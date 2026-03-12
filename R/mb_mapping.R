# ABOUTME: Joins mesh blocks to postcodes and calculates centroids
# ABOUTME: Filters outlier postcodes beyond a hard distance cutoff from the group centroid

library(sf)
library(dplyr)

build_mb_postcode_map <- function(mb_boundaries, mb_allocation, mb_population, postcode_summary) {
  mb_code_col <- grep("MB_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  mb_boundaries |>
    rename(mb_code = !!sym(mb_code_col)) |>
    mutate(mb_code = as.character(mb_code)) |>
    st_centroid() |>
    mutate(
      centroid_lon = st_coordinates(geometry)[, 1],
      centroid_lat = st_coordinates(geometry)[, 2]
    ) |>
    st_drop_geometry() |>
    inner_join(mb_allocation, by = "mb_code") |>
    rename(postcode = poa_code) |>
    inner_join(mb_population, by = "mb_code") |>
    filter(postcode %in% postcode_summary$postcode, population > 0) |>
    st_as_sf(coords = c("centroid_lon", "centroid_lat"), crs = 4326, remove = FALSE)
}

filter_outlier_postcodes <- function(postcode_summary, poa_boundaries, max_distance_km = 150) {
  poa_code_col <- grep("POA_CODE", names(poa_boundaries), value = TRUE, ignore.case = TRUE)[1]

  # Compute each postcode's distance from the group centroid
  poa_centroids <- poa_boundaries |>
    rename(postcode = !!sym(poa_code_col)) |>
    mutate(postcode = as.character(postcode)) |>
    filter(postcode %in% postcode_summary$postcode) |>
    st_centroid()

  coords <- st_coordinates(poa_centroids)
  mean_centre <- st_sfc(st_point(c(mean(coords[, 1]), mean(coords[, 2]))), crs = st_crs(poa_centroids))

  poa_distances <- poa_centroids |>
    mutate(
      dist_to_centre_km = as.numeric(st_distance(geometry, mean_centre)) / 1000,
      is_outlier = dist_to_centre_km > max_distance_km
    ) |>
    st_drop_geometry() |>
    select(postcode, dist_to_centre_km, is_outlier)

  excluded <- poa_distances |> filter(is_outlier) |> pull(postcode)

  list(
    filtered_summary = postcode_summary |> filter(!postcode %in% excluded),
    excluded_postcodes = excluded,
    max_distance_km = max_distance_km
  )
}
