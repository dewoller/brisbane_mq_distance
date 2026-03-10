# ABOUTME: Tests for target location definitions
# ABOUTME: Validates coordinates, CRS, and structure of the 3 locations

library(testthat)
library(sf)

source(file.path(here::here(), "R", "locations.R"))

test_that("get_target_locations returns sf with 3 locations", {
  locs <- get_target_locations()
  expect_s3_class(locs, "sf")
  expect_equal(nrow(locs), 3)
  expect_equal(st_crs(locs)$epsg, 4326)
  expect_true(all(c("location_id", "name", "address", "role") %in% names(locs)))
})

test_that("location coordinates are in Brisbane region", {
  locs <- get_target_locations()
  coords <- st_coordinates(locs)
  # Brisbane is roughly lon 152.5-153.5, lat -28 to -27
  expect_true(all(coords[, 1] > 152.5 & coords[, 1] < 153.5))
  expect_true(all(coords[, 2] > -28 & coords[, 2] < -27))
})
