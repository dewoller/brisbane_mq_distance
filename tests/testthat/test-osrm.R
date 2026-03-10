# ABOUTME: Tests for OSRM API query building and response parsing
# ABOUTME: Tests marked 'osrm_live' require http://louisa_ts:5000 to be running

library(testthat)
library(tibble)

source(file.path(here::here(), "R", "osrm.R"))

test_that("build_osrm_table_url constructs correct URL", {
  sources <- tibble(lon = c(153.0, 153.1), lat = c(-27.5, -27.6))
  destinations <- tibble(lon = c(153.03, 152.91), lat = c(-27.51, -27.56))

  url <- build_osrm_table_url(
    sources, destinations,
    base_url = "http://louisa_ts:5000"
  )

  expect_true(grepl("^http://louisa_ts:5000/table/v1/driving/", url))
  expect_true(grepl("sources=0;1", url))
  expect_true(grepl("destinations=2;3", url))
  expect_true(grepl("annotations=duration,distance", url))
  # Check coordinates are in lon,lat format
  expect_true(grepl("153,-27.5;153.1,-27.6;153.03,-27.51;152.91,-27.56", url))
})

test_that("parse_osrm_table_response extracts duration and distance matrices", {
  # Simulated OSRM response structure
  response <- list(
    code = "Ok",
    durations = matrix(c(100, 200, 300, 400), nrow = 2, ncol = 2),
    distances = matrix(c(1000, 2000, 3000, 4000), nrow = 2, ncol = 2)
  )
  mb_codes <- c("MB_A", "MB_B")
  loc_ids <- c("loc_1", "loc_2")

  result <- parse_osrm_table_response(response, mb_codes, loc_ids)

  expect_equal(nrow(result), 4)  # 2 MBs x 2 locations
  expect_true(all(c("mb_code", "location_id", "duration_sec", "distance_m") %in% names(result)))
  expect_equal(result$duration_sec[result$mb_code == "MB_A" & result$location_id == "loc_1"], 100)
  expect_equal(result$distance_m[result$mb_code == "MB_B" & result$location_id == "loc_2"], 4000)
})

test_that("chunk_indices creates correct batches", {
  chunks <- chunk_indices(250, chunk_size = 100)
  expect_equal(length(chunks), 3)
  expect_equal(chunks[[1]], 1:100)
  expect_equal(chunks[[2]], 101:200)
  expect_equal(chunks[[3]], 201:250)
})
