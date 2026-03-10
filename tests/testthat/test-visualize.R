# ABOUTME: Tests for visualization output functions
# ABOUTME: Validates that plots, map, and table produce output files without error

library(testthat)
library(tibble)
library(dplyr)
library(sf)

source(file.path(here::here(), "R", "visualize.R"))

# Shared test fixtures
make_test_routes <- function() {
  tibble(
    mb_code = rep(c("MB_A", "MB_B"), each = 3),
    postcode = rep("4000", 6),
    location_id = rep(c("loc_1", "loc_2", "loc_3"), 2),
    spread_individuals = rep(c(6, 4), each = 3),
    spread_households = rep(c(2, 1), each = 3),
    distance_km = c(10, 20, 15, 12, 22, 17),
    duration_min = c(15, 25, 20, 18, 28, 22),
    distance_m = distance_km * 1000,
    duration_sec = duration_min * 60
  )
}

make_test_locations <- function() {
  st_as_sf(
    tibble(
      location_id = c("loc_1", "loc_2", "loc_3"),
      name = c("Annerley", "Riverhills", "Fortitude Valley"),
      address = c("628 Ipswich Rd", "9 Pallinup St", "33 Baxter St"),
      role = c("Candidate", "Candidate", "Current"),
      lon = c(153.034, 152.914, 153.036),
      lat = c(-27.51, -27.559, -27.456)
    ),
    coords = c("lon", "lat"), crs = 4326
  )
}

make_test_postcode_location_stats <- function() {
  tibble(
    postcode = rep("4000", 3),
    location_id = c("loc_1", "loc_2", "loc_3"),
    n_individuals = rep(10, 3),
    n_households = rep(3, 3),
    weighted_mean_distance_km = c(11, 21, 16),
    weighted_mean_duration_min = c(16.2, 26.2, 20.8),
    min_mb_distance_km = c(10, 20, 15),
    max_mb_distance_km = c(12, 22, 17),
    min_mb_duration_min = c(15, 25, 20),
    max_mb_duration_min = c(18, 28, 22),
    avg_household_size = rep(10 / 3, 3)
  )
}

make_test_location_summary <- function() {
  tibble(
    location_id = c("loc_1", "loc_2", "loc_3"),
    total_individuals = c(10, 10, 10),
    total_households = c(3, 3, 3),
    weighted_mean_distance_km = c(11, 21, 16),
    weighted_mean_duration_min = c(16.2, 26.2, 20.8),
    pct_within_15min = c(40, 0, 0),
    pct_within_30min = c(100, 80, 100),
    pct_within_45min = c(100, 100, 100),
    pct_within_60min = c(100, 100, 100),
    weighted_median_duration_min = c(16.2, 26.2, 20.8),
    p25_duration_min = c(15, 25, 20),
    p75_duration_min = c(18, 28, 22)
  )
}

test_that("make_violin_plots produces a PNG file", {
  routes <- make_test_routes()
  locs <- make_test_locations()
  withr::with_tempdir({
    dir.create("output")
    out <- make_violin_plots(routes, locs)
    expect_true(file.exists(out))
    expect_true(grepl("\\.png$", out))
  })
})

test_that("make_map produces an HTML file", {
  locs <- make_test_locations()
  pc_loc_stats <- make_test_postcode_location_stats()
  filtered_pcs <- tibble(
    postcode = "4000",
    n_individuals = 10,
    n_households = 3,
    avg_household_size = 10 / 3
  )
  # Build a minimal POA boundary for postcode 4000
  poa_bounds <- st_sf(
    POA_CODE_2021 = "4000",
    geometry = st_sfc(
      st_polygon(list(matrix(
        c(153.0, -27.5,
          153.1, -27.5,
          153.1, -27.6,
          153.0, -27.6,
          153.0, -27.5),
        ncol = 2, byrow = TRUE
      )))
    ),
    crs = 4326
  )

  withr::with_tempdir({
    dir.create("output")
    out <- make_map(poa_bounds, pc_loc_stats, locs, filtered_pcs)
    expect_true(file.exists(out))
    expect_true(grepl("\\.html$", out))
  })
})

test_that("make_summary_table_gt produces an HTML file", {
  locs <- make_test_locations()
  loc_summary <- make_test_location_summary()

  withr::with_tempdir({
    dir.create("output")
    out <- make_summary_table_gt(loc_summary, locs)
    expect_true(file.exists(out))
    expect_true(grepl("\\.html$", out))
  })
})
