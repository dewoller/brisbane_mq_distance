# ABOUTME: Tests for mesh block to postcode mapping and outlier exclusion
# ABOUTME: Uses synthetic spatial data to validate join and filtering logic

library(testthat)
library(sf)
library(tibble)
library(dplyr)
source("../../R/mb_mapping.R")

test_that("build_mb_postcode_map joins MB to postcodes with centroids", {
  # Create synthetic MB boundaries (2 MBs)
  mb_bounds <- st_sf(
    MB_CODE_2021 = c("30000001", "30000002"),
    geometry = st_sfc(
      st_point(c(153.0, -27.5)),
      st_point(c(153.1, -27.6))
    ),
    crs = 4326
  ) |> st_buffer(0.01)

  mb_alloc <- tibble(mb_code = c("30000001", "30000002"), poa_code = c("4000", "4001"))
  mb_pop <- tibble(mb_code = c("30000001", "30000002"), population = c(100, 200))
  pc_summary <- tibble(postcode = c("4000", "4001"), n_individuals = c(10, 5), n_households = c(3, 2), avg_household_size = c(10/3, 5/2))

  result <- build_mb_postcode_map(mb_bounds, mb_alloc, mb_pop, pc_summary)

  expect_s3_class(result, "sf")
  expect_true("mb_code" %in% names(result))
  expect_true("postcode" %in% names(result))
  expect_true("population" %in% names(result))
  expect_true("centroid_lon" %in% names(result))
  expect_true("centroid_lat" %in% names(result))
  expect_equal(nrow(result), 2)
})

test_that("build_mb_postcode_map excludes MBs with zero population", {
  mb_bounds <- st_sf(
    MB_CODE_2021 = c("30000001", "30000002", "30000003"),
    geometry = st_sfc(
      st_point(c(153.0, -27.5)),
      st_point(c(153.1, -27.6)),
      st_point(c(153.2, -27.7))
    ),
    crs = 4326
  ) |> st_buffer(0.01)

  mb_alloc <- tibble(mb_code = c("30000001", "30000002", "30000003"), poa_code = c("4000", "4000", "4001"))
  mb_pop <- tibble(mb_code = c("30000001", "30000002", "30000003"), population = c(100, 0, 200))
  pc_summary <- tibble(postcode = c("4000", "4001"), n_individuals = c(10, 5), n_households = c(3, 2), avg_household_size = c(10/3, 5/2))

  result <- build_mb_postcode_map(mb_bounds, mb_alloc, mb_pop, pc_summary)
  expect_equal(nrow(result), 2)  # MB with 0 pop excluded
})

test_that("filter_outlier_postcodes removes postcodes > 3 SD from mean distance", {
  # 10 clustered postcodes + 1 extreme outlier
  # Need enough clustered points so the outlier doesn't dominate the SD calculation
  close_postcodes <- sprintf("40%02d", 0:9)
  close_lons <- seq(153.0, 153.009, length.out = 10)
  close_lats <- seq(-27.5, -27.509, length.out = 10)

  all_postcodes <- c(close_postcodes, "9999")
  all_lons <- c(close_lons, 130.0)
  all_lats <- c(close_lats, -12.0)  # Darwin - very far away

  pc_summary <- tibble(
    postcode = all_postcodes,
    n_individuals = rep(10, 11),
    n_households = rep(3, 11),
    avg_household_size = rep(10/3, 11)
  )
  poa_bounds <- st_sf(
    POA_CODE_2021 = all_postcodes,
    geometry = st_sfc(
      lapply(seq_along(all_lons), function(i) st_point(c(all_lons[i], all_lats[i])))
    ),
    crs = 4326
  ) |> st_buffer(0.01)

  result <- filter_outlier_postcodes(pc_summary, poa_bounds)
  expect_true("9999" %in% result$excluded_postcodes)
  expect_false("9999" %in% result$filtered_summary$postcode)
  expect_equal(nrow(result$filtered_summary), 10)
})
