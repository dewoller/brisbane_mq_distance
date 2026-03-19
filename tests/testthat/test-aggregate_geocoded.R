# ABOUTME: Tests for geocoded route aggregation to location-level stats
# ABOUTME: Validates simple means (no weighting), percentiles, and time-band percentages

library(testthat)
library(tibble)
library(dplyr)
source(file.path(here::here(), "R", "aggregate_geocoded.R"))

test_that("aggregate_geo_location computes correct stats per location", {
  routes <- tibble(
    individual_id = c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5),
    household_id = c(1, 1, 2, 2, 3, 1, 1, 2, 2, 3),
    postcode = rep("4000", 10),
    location_id = c(rep("loc_1", 5), rep("loc_2", 5)),
    duration_min = c(10, 20, 30, 40, 50, 15, 25, 35, 45, 55),
    distance_km = c(5, 10, 15, 20, 25, 7.5, 12.5, 17.5, 22.5, 27.5),
    duration_sec = c(10, 20, 30, 40, 50, 15, 25, 35, 45, 55) * 60,
    distance_m = c(5, 10, 15, 20, 25, 7.5, 12.5, 17.5, 22.5, 27.5) * 1000
  )

  result <- aggregate_geo_location(routes)
  expect_equal(nrow(result), 2)

  loc1 <- result |> filter(location_id == "loc_1")
  expect_equal(loc1$n_individuals, 5)
  expect_equal(loc1$n_households, 3)
  expect_equal(loc1$mean_duration_min, mean(c(10, 20, 30, 40, 50)))
  expect_equal(loc1$mean_distance_km, mean(c(5, 10, 15, 20, 25)))
  # All 5 are <= 60 min
  expect_equal(loc1$pct_within_60min, 100)
  # 1 of 5 are <= 15 min
  expect_equal(loc1$pct_within_15min, 20)
})

test_that("build_geo_full_matrix returns all columns", {
  routes <- tibble(
    individual_id = c(1, 2, 1, 2),
    household_id = c(1, 2, 1, 2),
    postcode = c("4000", "4001", "4000", "4001"),
    location_id = c("loc_1", "loc_1", "loc_2", "loc_2"),
    duration_min = c(10, 20, 30, 40),
    distance_km = c(5, 10, 15, 20),
    duration_sec = c(600, 1200, 1800, 2400),
    distance_m = c(5000, 10000, 15000, 20000)
  )

  result <- build_geo_full_matrix(routes)
  expect_equal(nrow(result), 4)
  expect_true(all(c("individual_id", "household_id", "postcode", "location_id",
                     "duration_min", "distance_km") %in% names(result)))
})
