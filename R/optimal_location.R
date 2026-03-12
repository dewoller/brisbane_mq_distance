# ABOUTME: Finds optimal facility locations by testing each client postcode centroid as a candidate
# ABOUTME: Ranks candidates by total person-minutes (individuals x travel time) via OSRM routing

library(sf)
library(dplyr)
library(purrr)
library(httr2)
library(tibble)
library(tidyr)

build_candidate_locations <- function(poa_boundaries, filtered_postcodes, radius_km = 50) {
  poa_code_col <- grep("POA_CODE", names(poa_boundaries), value = TRUE, ignore.case = TRUE)[1]

  all_poa <- poa_boundaries |>
    rename(postcode = !!sym(poa_code_col)) |>
    mutate(postcode = as.character(postcode))

  # Compute centroid of client postcodes as the reference point
  client_poa <- all_poa |> filter(postcode %in% filtered_postcodes$postcode)
  client_centroid <- st_centroid(st_union(client_poa))

  # Include all QLD postcodes within radius_km of the client centroid
  qld_poa <- all_poa |> filter(grepl("^4", postcode))
  qld_centroids <- qld_poa |> st_centroid()
  dists <- as.numeric(st_distance(qld_centroids, client_centroid)) / 1000

  qld_poa |>
    filter(dists <= radius_km) |>
    st_centroid() |>
    mutate(
      location_id = paste0("poa_", postcode),
      lon = st_coordinates(geometry)[, 1],
      lat = st_coordinates(geometry)[, 2],
      has_clients = postcode %in% filtered_postcodes$postcode
    )
}

route_mb_to_candidates <- function(mb_weights, candidate_locations,
                                   osrm_url = "http://totoro.magpie-inconnu.ts.net:5001") {
  mb_data <- mb_weights |>
    st_drop_geometry() |>
    select(mb_code, postcode, centroid_lon, centroid_lat, spread_individuals, spread_households)

  candidate_coords <- candidate_locations |>
    st_drop_geometry() |>
    select(location_id, lon, lat)

  # Batch candidates to stay within OSRM coordinate limits (~100 total)
  dest_batch_size <- 20
  src_chunk_size <- 75  # 75 sources + 20 destinations = 95 (under 100 limit)

  n_candidates <- nrow(candidate_coords)
  dest_batches <- chunk_indices(n_candidates, dest_batch_size)

  message("Routing ", nrow(mb_data), " mesh blocks to ", n_candidates, " candidate locations")

  map(seq_along(dest_batches), function(di) {
    dest_batch <- candidate_coords |> slice(dest_batches[[di]])
    dest_tibble <- dest_batch |> select(lon, lat)
    dest_ids <- dest_batch$location_id

    message("  Destination batch ", di, "/", length(dest_batches),
            " (", length(dest_batches[[di]]), " candidates)")

    src_chunks <- chunk_indices(nrow(mb_data), src_chunk_size)

    map(src_chunks, function(src_idx) {
      chunk <- mb_data |> slice(src_idx)

      chunk |>
        select(lon = centroid_lon, lat = centroid_lat) |>
        build_osrm_table_url(dest_tibble, base_url = osrm_url) |>
        request() |>
        req_timeout(120) |>
        req_retry(max_tries = 3, backoff = ~ 2) |>
        req_perform() |>
        resp_body_json() |>
        (\(resp) {
          if (resp$code != "Ok") { warning("OSRM error: ", resp$code); return(NULL) }
          parse_osrm_table_response(resp, chunk$mb_code, dest_ids)
        })() |>
        left_join(
          chunk |> select(mb_code, postcode, spread_individuals, spread_households),
          by = "mb_code"
        )
    }, .progress = TRUE) |>
      bind_rows()
  }) |>
    bind_rows() |>
    mutate(
      distance_km = distance_m / 1000,
      duration_min = duration_sec / 60
    )
}

rank_candidate_locations <- function(candidate_routes) {
  candidate_routes |>
    group_by(location_id) |>
    summarise(
      total_person_minutes = sum(spread_individuals * duration_min, na.rm = TRUE),
      total_person_km = sum(spread_individuals * distance_km, na.rm = TRUE),
      weighted_mean_duration_min = weighted.mean(duration_min, spread_individuals, na.rm = TRUE),
      weighted_mean_distance_km = weighted.mean(distance_km, spread_individuals, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(total_person_minutes) |>
    mutate(
      rank = row_number(),
      candidate_postcode = sub("^poa_", "", location_id)
    ) |>
    select(rank, candidate_postcode, total_person_minutes, total_person_km,
           weighted_mean_duration_min, weighted_mean_distance_km)
}

compare_candidates_to_locations <- function(candidate_ranking, mb_routes, locations, n_top = 10) {
  existing_stats <- mb_routes |>
    group_by(location_id) |>
    summarise(
      total_person_minutes = sum(spread_individuals * duration_min, na.rm = TRUE),
      total_person_km = sum(spread_individuals * distance_km, na.rm = TRUE),
      weighted_mean_duration_min = weighted.mean(duration_min, spread_individuals, na.rm = TRUE),
      weighted_mean_distance_km = weighted.mean(distance_km, spread_individuals, na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(
      locations |> st_drop_geometry() |> select(location_id, name),
      by = "location_id"
    ) |>
    mutate(type = "existing")

  candidate_top <- candidate_ranking |>
    head(n_top) |>
    mutate(
      location_id = paste0("poa_", candidate_postcode),
      name = paste0("Postcode ", candidate_postcode),
      type = "candidate"
    )

  bind_rows(
    existing_stats |> select(location_id, name, type, total_person_minutes, total_person_km,
                             weighted_mean_duration_min, weighted_mean_distance_km),
    candidate_top |> select(location_id, name, type, total_person_minutes, total_person_km,
                            weighted_mean_duration_min, weighted_mean_distance_km)
  ) |>
    arrange(total_person_minutes) |>
    mutate(rank = row_number())
}
