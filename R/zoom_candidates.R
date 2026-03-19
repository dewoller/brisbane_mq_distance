# ABOUTME: Finds optimal mesh block locations by routing all individuals to all MBs within a radius
# ABOUTME: Routes geocoded individuals to candidate centroids via OSRM, ranks by mean travel time

library(dplyr)
library(purrr)
library(sf)
library(httr2)
library(tibble)

route_population_to_centroids <- function(individuals_sf, candidate_centroids,
                                          area_code_col = "area_code",
                                          osrm_url = "http://totoro.magpie-inconnu.ts.net:5001") {
  ind_coords <- individuals_sf |>
    mutate(
      ind_lon = st_coordinates(geometry)[, 1],
      ind_lat = st_coordinates(geometry)[, 2],
      ind_id = as.character(row_number())
    ) |>
    st_drop_geometry()

  cand_data <- candidate_centroids |>
    st_drop_geometry() |>
    select(area_code = !!sym(area_code_col), lon = centroid_lon, lat = centroid_lat) |>
    filter(!is.na(lon), !is.na(lat))

  # Batch candidates (destinations) in groups of 20, sources in groups of 75
  dest_batch_size <- 20
  src_chunk_size <- 75

  dest_batches <- chunk_indices(nrow(cand_data), dest_batch_size)

  message("Routing ", nrow(ind_coords), " individuals to ", nrow(cand_data), " candidate centroids")

  all_results <- map(seq_along(dest_batches), function(di) {
    dest_batch <- cand_data |> slice(dest_batches[[di]])
    dest_tibble <- dest_batch |> select(lon, lat)
    dest_ids <- dest_batch$area_code

    src_chunks <- chunk_indices(nrow(ind_coords), src_chunk_size)

    map(src_chunks, function(src_idx) {
      chunk <- ind_coords |> slice(src_idx)

      chunk |>
        select(lon = ind_lon, lat = ind_lat) |>
        build_osrm_table_url(dest_tibble, base_url = osrm_url) |>
        request() |>
        req_timeout(120) |>
        req_retry(max_tries = 3, backoff = ~ 2) |>
        req_perform() |>
        resp_body_json() |>
        (\(resp) {
          if (resp$code != "Ok") { warning("OSRM error: ", resp$code); return(NULL) }
          parse_osrm_table_response(resp, chunk$ind_id, dest_ids)
        })()
    }, .progress = TRUE) |>
      bind_rows()
  }) |>
    bind_rows() |>
    mutate(
      duration_min = duration_sec / 60,
      distance_km = distance_m / 1000
    )

  # Summarise: mean travel time per candidate
  # mb_code holds individual IDs (sources), location_id holds area codes (destinations)
  all_results |>
    group_by(area_code = location_id) |>
    summarise(
      mean_duration_min = mean(duration_min, na.rm = TRUE),
      mean_distance_km = mean(distance_km, na.rm = TRUE),
      .groups = "drop"
    )
}

route_all_mb_within_radius <- function(individuals_sf, mb_boundaries, radius_km = 50,
                                       osrm_url = "http://totoro.magpie-inconnu.ts.net:5001") {
  mb_code_col <- grep("MB_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  # Compute centroid of all individuals as the reference point
  ind_centroid <- st_centroid(st_union(individuals_sf))

  # Compute MB centroids and filter to within radius
  # Transform to match CRS if needed (MB boundaries may be GDA2020)
  mb_with_centroids <- mb_boundaries |>
    st_transform(st_crs(individuals_sf)) |>
    rename(area_code = !!sym(mb_code_col))

  mb_centroids <- st_centroid(mb_with_centroids)
  dists_km <- as.numeric(st_distance(mb_centroids, ind_centroid)) / 1000

  mb_candidates <- mb_with_centroids |>
    filter(dists_km <= radius_km)

  mb_candidates$centroid_lon <- st_coordinates(st_centroid(mb_candidates))[, 1]
  mb_candidates$centroid_lat <- st_coordinates(st_centroid(mb_candidates))[, 2]

  message("Found ", nrow(mb_candidates), " mesh blocks within ", radius_km, "km of population centroid")

  mb_results <- route_population_to_centroids(individuals_sf, mb_candidates, "area_code", osrm_url)
  message("Routed to ", nrow(mb_results), " mesh blocks")

  ranking <- mb_results |>
    arrange(mean_duration_min) |>
    mutate(rank = row_number())

  list(
    mb = mb_results,
    ranking = ranking
  )
}
