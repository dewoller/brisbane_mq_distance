# ABOUTME: Progressive zoom optimal location finder via SA3 -> SA2 -> SA1 -> MB funnel
# ABOUTME: Routes geocoded individuals to candidate centroids, keeping top N% at each level

library(dplyr)
library(purrr)
library(sf)
library(httr2)
library(tibble)

zoom_filter <- function(candidate_results, top_pct = 0.10) {
  n_keep <- max(1, ceiling(nrow(candidate_results) * top_pct))
  candidate_results |>
    arrange(mean_duration_min) |>
    head(n_keep) |>
    pull(area_code)
}

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

run_progressive_zoom <- function(individuals_sf, sa3_boundaries, sa2_boundaries,
                                  sa1_boundaries, mb_boundaries,
                                  osrm_url = "http://totoro.magpie-inconnu.ts.net:5001") {
  # Identify SA3 code column
  sa3_code_col <- grep("SA3_CODE", names(sa3_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa2_code_col <- grep("SA2_CODE", names(sa2_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa1_code_col <- grep("SA1_CODE", names(sa1_boundaries), value = TRUE, ignore.case = TRUE)[1]
  mb_code_col <- grep("MB_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  # SA2-in-SA3 and SA1-in-SA2 mapping columns
  sa2_in_sa3_col <- grep("SA3_CODE", names(sa2_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa1_in_sa2_col <- grep("SA2_CODE", names(sa1_boundaries), value = TRUE, ignore.case = TRUE)[1]
  mb_in_sa1_col <- grep("SA1_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  # --- Level 1: SA3 (keep 30%) ---
  message("=== Zoom Level 1: SA3 ===")
  sa3_candidates <- sa3_boundaries |>
    rename(area_code = !!sym(sa3_code_col))
  sa3_results <- route_population_to_centroids(individuals_sf, sa3_candidates, "area_code", osrm_url)
  sa3_survivors <- zoom_filter(sa3_results, 0.30)
  message("SA3: ", length(sa3_survivors), " of ", nrow(sa3_results), " survive")

  # --- Level 2: SA2 within surviving SA3s (keep 20%) ---
  message("=== Zoom Level 2: SA2 ===")
  sa2_candidates <- sa2_boundaries |>
    filter(!!sym(sa2_in_sa3_col) %in% sa3_survivors) |>
    rename(area_code = !!sym(sa2_code_col))
  sa2_results <- route_population_to_centroids(individuals_sf, sa2_candidates, "area_code", osrm_url)
  sa2_survivors <- zoom_filter(sa2_results, 0.20)
  message("SA2: ", length(sa2_survivors), " of ", nrow(sa2_results), " survive")

  # --- Level 3: SA1 within surviving SA2s (keep 10%) ---
  message("=== Zoom Level 3: SA1 ===")
  sa1_candidates <- sa1_boundaries |>
    filter(!!sym(sa1_in_sa2_col) %in% sa2_survivors) |>
    rename(area_code = !!sym(sa1_code_col))
  sa1_results <- route_population_to_centroids(individuals_sf, sa1_candidates, "area_code", osrm_url)
  sa1_survivors <- zoom_filter(sa1_results, 0.10)
  message("SA1: ", length(sa1_survivors), " of ", nrow(sa1_results), " survive")

  # --- Level 4: MB within surviving SA1s (keep 10%) ---
  message("=== Zoom Level 4: Mesh Blocks ===")
  mb_candidates <- mb_boundaries |>
    filter(!!sym(mb_in_sa1_col) %in% sa1_survivors) |>
    rename(area_code = !!sym(mb_code_col))

  # Compute centroids for MBs if not already present
  if (!"centroid_lon" %in% names(mb_candidates)) {
    mb_centroids <- st_centroid(mb_candidates)
    mb_candidates$centroid_lon <- st_coordinates(mb_centroids)[, 1]
    mb_candidates$centroid_lat <- st_coordinates(mb_centroids)[, 2]
  }

  mb_results <- route_population_to_centroids(individuals_sf, mb_candidates, "area_code", osrm_url)
  mb_survivors <- zoom_filter(mb_results, 0.10)
  message("MB: ", length(mb_survivors), " of ", nrow(mb_results), " survive")

  # Build final ranking
  ranking <- mb_results |>
    arrange(mean_duration_min) |>
    mutate(rank = row_number())

  list(
    sa3 = sa3_results,
    sa2 = sa2_results,
    sa1 = sa1_results,
    mb = mb_results,
    ranking = ranking
  )
}
