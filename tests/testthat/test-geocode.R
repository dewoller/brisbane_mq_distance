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
