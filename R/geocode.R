# ABOUTME: Reads new Brisbane Family Excel data and geocodes addresses via ArcGIS
# ABOUTME: Falls back to postcode centroid for missing/failed geocodes

library(readxl)
library(dplyr)
library(tidyr)
library(tidygeocoder)
library(sf)

read_geocoded_data <- function(path) {
  raw <- read_excel(path, sheet = "Raw Data")
  # Column names contain \r\n artifacts — select by position and rename
  col_names <- c("individual_id", "household_id", "address", "suburb", "state", "postcode")
  names(raw) <- col_names
  raw |>
    mutate(postcode = as.character(as.integer(postcode))) |>
    filter(!is.na(postcode))
}

geocode_addresses <- function(raw_data) {
  unique_addresses <- raw_data |>
    filter(!is.na(address)) |>
    distinct(address, suburb, postcode, .keep_all = FALSE) |>
    mutate(
      full_address = paste(address, suburb, "Queensland", postcode, sep = ", ")
    )

  geocoded <- unique_addresses |>
    tidygeocoder::geocode(
      address = full_address,
      method = "arcgis",
      lat = "geo_lat",
      long = "geo_lon"
    )

  geocoded |>
    mutate(geo_success = !is.na(geo_lon) & !is.na(geo_lat)) |>
    select(address, suburb, postcode, geo_lon, geo_lat, geo_success)
}

assign_locations <- function(raw_data, geocoded_lookup, poa_boundaries) {
  # Join geocoded coords to individuals by address + suburb + postcode
  with_coords <- raw_data |>
    left_join(
      geocoded_lookup |> filter(geo_success),
      by = c("address", "suburb", "postcode")
    )

  # Compute POA centroids for fallback
  poa_code_col <- grep("POA_CODE", names(poa_boundaries), value = TRUE, ignore.case = TRUE)[1]
  poa_centroids <- poa_boundaries |>
    rename(postcode = !!sym(poa_code_col)) |>
    mutate(postcode = as.character(postcode)) |>
    st_centroid() |>
    mutate(
      poa_lon = st_coordinates(geometry)[, 1],
      poa_lat = st_coordinates(geometry)[, 2]
    ) |>
    st_drop_geometry() |>
    select(postcode, poa_lon, poa_lat)

  # Fill missing geocodes with POA centroid
  result <- with_coords |>
    left_join(poa_centroids, by = "postcode") |>
    mutate(
      final_lon = if_else(is.na(geo_lon), poa_lon, geo_lon),
      final_lat = if_else(is.na(geo_lat), poa_lat, geo_lat)
    ) |>
    select(individual_id, household_id, address, suburb, state, postcode,
           final_lon, final_lat, geo_success) |>
    mutate(geo_success = replace_na(geo_success, FALSE)) |>
    st_as_sf(coords = c("final_lon", "final_lat"), crs = 4326)

  result
}

filter_outlier_individuals <- function(geo_individuals, max_distance_km = 150) {
  # Compute mean centre of all individuals
  coords <- st_coordinates(geo_individuals)
  mean_centre <- st_sfc(st_point(c(mean(coords[, 1]), mean(coords[, 2]))), crs = 4326)

  # Calculate distance from mean centre for each individual
  dists_km <- as.numeric(st_distance(geo_individuals, mean_centre)) / 1000
  n_before <- nrow(geo_individuals)
  result <- geo_individuals |> filter(dists_km <= max_distance_km)
  n_removed <- n_before - nrow(result)
  if (n_removed > 0) {
    message("Removed ", n_removed, " individuals > ", max_distance_km, "km from group centroid")
  }
  result
}
