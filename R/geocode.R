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
