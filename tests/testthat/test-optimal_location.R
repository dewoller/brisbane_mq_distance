# ABOUTME: Tests for optimal facility location ranking logic
# ABOUTME: Verifies that total person-minutes calculation correctly ranks candidates

library(testthat)
library(tibble)
library(dplyr)

source(file.path(here::here(), "R", "osrm.R"))
source(file.path(here::here(), "R", "optimal_location.R"))

test_that("rank_candidate_locations computes correct totals and ranking", {
  routes <- tibble(
    location_id = rep(c("poa_4000", "poa_4001"), each = 3),
    mb_code = rep(c("MB1", "MB2", "MB3"), 2),
    spread_individuals = rep(c(10, 20, 30), 2),
    duration_min = c(10, 20, 30, 5, 10, 15),
    distance_km = c(10, 20, 30, 5, 10, 15),
    duration_sec = c(600, 1200, 1800, 300, 600, 900),
    distance_m = c(10000, 20000, 30000, 5000, 10000, 15000),
    postcode = rep("origin", 6),
    spread_households = rep(c(5, 10, 15), 2)
  )

  result <- rank_candidate_locations(routes)

  expect_equal(nrow(result), 2)
  expect_equal(result$candidate_postcode[1], "4001")
  expect_equal(result$candidate_postcode[2], "4000")
  expect_equal(result$rank, c(1, 2))

  # poa_4001: 10*5 + 20*10 + 30*15 = 50 + 200 + 450 = 700
  expect_equal(result$total_person_minutes[1], 700)
  # poa_4000: 10*10 + 20*20 + 30*30 = 100 + 400 + 900 = 1400
  expect_equal(result$total_person_minutes[2], 1400)
})

test_that("rank_candidate_locations handles NA durations gracefully", {
  routes <- tibble(
    location_id = rep("poa_4000", 3),
    mb_code = c("MB1", "MB2", "MB3"),
    spread_individuals = c(10, 20, 30),
    duration_min = c(10, NA, 30),
    distance_km = c(10, NA, 30),
    duration_sec = c(600, NA, 1800),
    distance_m = c(10000, NA, 30000),
    postcode = rep("origin", 3),
    spread_households = c(5, 10, 15)
  )

  result <- rank_candidate_locations(routes)

  expect_equal(nrow(result), 1)
  # Only MB1 and MB3 contribute: 10*10 + 30*30 = 100 + 900 = 1000
  expect_equal(result$total_person_minutes[1], 1000)
})

test_that("compare_candidates_to_locations combines and ranks correctly", {
  candidate_ranking <- tibble(
    rank = 1:3,
    candidate_postcode = c("4000", "4001", "4002"),
    total_person_minutes = c(500, 600, 700),
    total_person_km = c(50, 60, 70),
    weighted_mean_duration_min = c(8.3, 10.0, 11.7),
    weighted_mean_distance_km = c(8.3, 10.0, 11.7)
  )

  mb_routes <- tibble(
    location_id = rep(c("loc_1", "loc_2"), each = 3),
    mb_code = rep(c("MB1", "MB2", "MB3"), 2),
    spread_individuals = rep(c(10, 20, 30), 2),
    duration_min = c(15, 25, 35, 10, 20, 30),
    distance_km = c(15, 25, 35, 10, 20, 30),
    spread_households = rep(c(5, 10, 15), 2)
  )

  locations <- tibble(
    location_id = c("loc_1", "loc_2"),
    name = c("Site A", "Site B")
  )

  result <- compare_candidates_to_locations(candidate_ranking, mb_routes, locations, n_top = 3)

  expect_true("type" %in% names(result))
  expect_true(all(c("existing", "candidate") %in% result$type))
  # Should be sorted by total_person_minutes
  expect_true(all(diff(result$total_person_minutes) >= 0))
})
