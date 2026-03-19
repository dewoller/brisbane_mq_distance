# ABOUTME: Tests for geocoding functions — data reading, address geocoding, location assignment
# ABOUTME: Uses the real Brisbane Family data March 2026.xlsx for reading tests

library(testthat)
library(tibble)
library(dplyr)
source(file.path(here::here(), "R", "geocode.R"))

test_that("read_geocoded_data returns cleaned tibble with correct columns", {
  df <- read_geocoded_data(file.path(here::here(), "data", "Brisbane Family data March 2026.xlsx"))
  expect_s3_class(df, "tbl_df")
  expect_named(df, c("individual_id", "household_id", "address", "suburb", "state", "postcode"))
  expect_type(df$individual_id, "double")
  expect_type(df$household_id, "double")
  expect_type(df$postcode, "character")
  expect_equal(nrow(df), 425)
  # All postcodes should be present
  expect_true(all(!is.na(df$postcode)))
  # Should have some addresses (368 of 425)
  expect_gt(sum(!is.na(df$address)), 300)
})

test_that("geocode_addresses returns lookup with expected columns", {
  # Use a small synthetic dataset to test the dedup and structure logic
  raw <- tibble(
    individual_id = 1:4,
    household_id = c(1, 1, 2, 3),
    address = c("544 Sandgate Road", "544 Sandgate Road", "27 Alleena Street", NA),
    suburb = c("Clayfield", "Clayfield", "Chermside", NA),
    state = c("Queensland", "Queensland", "Queensland", NA),
    postcode = c("4011", "4011", "4032", "4000")
  )
  result <- geocode_addresses(raw)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("address", "suburb", "postcode", "geo_lon", "geo_lat", "geo_success") %in% names(result)))
  # Should deduplicate — only 2 unique non-NA addresses
  expect_equal(nrow(result), 2)
  # NA addresses should be excluded from geocoding
  expect_false(any(is.na(result$address)))
})

test_that("geocode_addresses returns coordinates for known Brisbane address", {
  raw <- tibble(
    individual_id = 1,
    household_id = 1,
    address = "544 Sandgate Road",
    suburb = "Clayfield",
    state = "Queensland",
    postcode = "4011"
  )
  result <- geocode_addresses(raw)
  # ArcGIS should return coordinates near Brisbane
  expect_true(result$geo_success[1])
  expect_true(result$geo_lon[1] > 152 && result$geo_lon[1] < 154)
  expect_true(result$geo_lat[1] > -28 && result$geo_lat[1] < -27)
})
