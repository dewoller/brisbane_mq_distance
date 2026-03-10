# ABOUTME: Joins mesh blocks to postcodes and calculates centroids
# ABOUTME: Filters outlier postcodes more than 3 SD from the mean distance to the centroid

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

filter_outlier_postcodes <- function(postcode_summary, poa_boundaries) {
  poa_code_col <- grep("POA_CODE", names(poa_boundaries), value = TRUE, ignore.case = TRUE)[1]

  # Build distance-from-centre for each postcode in a single pipeline
  poa_distances <- poa_boundaries |>
    rename(postcode = !!sym(poa_code_col)) |>
    mutate(postcode = as.character(postcode)) |>
    filter(postcode %in% postcode_summary$postcode) |>
    st_centroid() |>
    mutate(
      coords = st_coordinates(geometry) |> as_tibble(),
      mean_lon = mean(coords$X),
      mean_lat = mean(coords$Y),
      mean_centre = st_sfc(st_point(c(first(mean_lon), first(mean_lat))), crs = 4326),
      dist_to_centre = as.numeric(st_distance(geometry, first(mean_centre)))
    ) |>
    st_drop_geometry() |>
    select(postcode, dist_to_centre) |>
    mutate(
      mean_dist = mean(dist_to_centre),
      sd_dist = sd(dist_to_centre),
      threshold = mean_dist + 3 * sd_dist,
      is_outlier = dist_to_centre > threshold
    )

  excluded <- poa_distances |> filter(is_outlier) |> pull(postcode)

  list(
    filtered_summary = postcode_summary |> filter(!postcode %in% excluded),
    excluded_postcodes = excluded,
    threshold_km = first(poa_distances$threshold) / 1000,
    mean_dist_km = first(poa_distances$mean_dist) / 1000,
    sd_dist_km = first(poa_distances$sd_dist) / 1000
  )
}
