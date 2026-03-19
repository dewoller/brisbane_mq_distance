# ABOUTME: Reads new Brisbane Family Excel data and geocodes addresses via ArcGIS
# ABOUTME: Falls back to postcode centroid for missing/failed geocodes

library(readxl)
library(dplyr)
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
