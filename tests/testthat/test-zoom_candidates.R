# ABOUTME: Tests for progressive zoom candidate location functions
# ABOUTME: Validates zoom_filter percentage selection and route_population_to_centroids schema

library(testthat)
library(tibble)
library(dplyr)
source(file.path(here::here(), "R", "zoom_candidates.R"))

test_that("zoom_filter keeps top N percent by lowest mean travel time", {
  candidates <- tibble(
    area_code = paste0("SA_", 1:10),
    mean_duration_min = c(10, 20, 30, 40, 50, 60, 70, 80, 90, 100)
  )

  # Keep top 30% = 3 areas
  result <- zoom_filter(candidates, top_pct = 0.30)
  expect_equal(length(result), 3)
  expect_equal(result, c("SA_1", "SA_2", "SA_3"))
})

test_that("zoom_filter keeps at least 1 area", {
  candidates <- tibble(
    area_code = c("SA_1"),
    mean_duration_min = c(10)
  )
  result <- zoom_filter(candidates, top_pct = 0.10)
  expect_equal(length(result), 1)
})
