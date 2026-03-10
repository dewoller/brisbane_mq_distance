# ABOUTME: Tests for aggregation of MB-level routes to postcode-level stats
# ABOUTME: Validates weighted means, min/max, and summary statistics

library(testthat)
library(tibble)
library(dplyr)
source("../../R/aggregate.R")

test_that("aggregate_postcode_location computes correct weighted stats", {
  routes <- tibble(
    mb_code = c("MB_A", "MB_B", "MB_A", "MB_B"),
    postcode = c("4000", "4000", "4000", "4000"),
    location_id = c("loc_1", "loc_1", "loc_2", "loc_2"),
    spread_individuals = c(6, 4, 6, 4),
    spread_households = c(2, 1, 2, 1),
    distance_km = c(10, 20, 30, 40),
    duration_min = c(15, 25, 35, 45),
    distance_m = c(10000, 20000, 30000, 40000),
    duration_sec = c(900, 1500, 2100, 2700)
  )

  result <- aggregate_postcode_location(routes)

  loc1 <- result |> filter(postcode == "4000", location_id == "loc_1")
  expect_equal(loc1$weighted_mean_distance_km, (6*10 + 4*20) / (6+4))  # 14
  expect_equal(loc1$weighted_mean_duration_min, (6*15 + 4*25) / (6+4))  # 19
  expect_equal(loc1$min_mb_distance_km, 10)
  expect_equal(loc1$max_mb_distance_km, 20)
  expect_equal(loc1$min_mb_duration_min, 15)
  expect_equal(loc1$max_mb_duration_min, 25)
})

test_that("summarise_locations computes overall weighted stats", {
  pc_loc <- tibble(
    postcode = c("4000", "4001", "4000", "4001"),
    location_id = c("loc_1", "loc_1", "loc_2", "loc_2"),
    n_individuals = c(10, 5, 10, 5),
    n_households = c(3, 2, 3, 2),
    weighted_mean_distance_km = c(10, 20, 30, 40),
    weighted_mean_duration_min = c(15, 25, 35, 45),
    min_mb_distance_km = c(8, 18, 28, 38),
    max_mb_distance_km = c(12, 22, 32, 42),
    min_mb_duration_min = c(13, 23, 33, 43),
    max_mb_duration_min = c(17, 27, 37, 47),
    avg_household_size = c(10/3, 5/2, 10/3, 5/2)
  )

  result <- summarise_locations(pc_loc)
  expect_equal(nrow(result), 2)  # 2 locations

  loc1 <- result |> filter(location_id == "loc_1")
  expected_mean <- (10*15 + 5*25) / (10+5)
  expect_equal(loc1$weighted_mean_duration_min, expected_mean)
})

test_that("build_full_matrix includes all postcode metadata", {
  pc_loc <- tibble(
    postcode = c("4000", "4001"),
    location_id = c("loc_1", "loc_1"),
    n_individuals = c(10, 5),
    n_households = c(3, 2),
    weighted_mean_distance_km = c(10, 20),
    weighted_mean_duration_min = c(15, 25),
    min_mb_distance_km = c(8, 18),
    max_mb_distance_km = c(12, 22),
    min_mb_duration_min = c(13, 23),
    max_mb_duration_min = c(17, 27),
    avg_household_size = c(10/3, 5/2)
  )
  filtered_pcs <- tibble(postcode = c("4000", "4001"), n_individuals = c(10, 5), n_households = c(3, 2), avg_household_size = c(10/3, 5/2))

  result <- build_full_matrix(pc_loc, filtered_pcs)
  expect_true("avg_household_size" %in% names(result))
  expect_equal(nrow(result), 2)
})
