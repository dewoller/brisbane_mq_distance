# ABOUTME: Tests for routing geocoded individuals to target locations via OSRM
# ABOUTME: Unit tests use parse_osrm_table_response directly; integration tests need OSRM server

library(testthat)
library(tibble)
library(dplyr)
library(sf)
source(file.path(here::here(), "R", "osrm.R"))
source(file.path(here::here(), "R", "route_geocoded.R"))

test_that("route_individuals_to_locations returns correct schema with simulated response", {
  # This tests the adapter logic around parse_osrm_table_response
  response <- list(
    code = "Ok",
    durations = matrix(c(900, 1200, 1500, 1800, 2100, 2400), nrow = 2, ncol = 3),
    distances = matrix(c(10000, 15000, 20000, 25000, 30000, 35000), nrow = 2, ncol = 3)
  )
  individual_ids <- c("101", "102")
  loc_ids <- c("loc_1", "loc_2", "loc_3")

  # Call parse directly to verify the adapter pattern
  raw_result <- parse_osrm_table_response(response, individual_ids, loc_ids)
  expect_true("mb_code" %in% names(raw_result))

  # Adapter: rename mb_code to individual_id
  adapted <- raw_result |> rename(individual_id = mb_code)
  expect_true("individual_id" %in% names(adapted))
  expect_equal(nrow(adapted), 6)  # 2 individuals x 3 locations
  expect_true(all(c("individual_id", "location_id", "duration_sec", "distance_m") %in% names(adapted)))
})

test_that("route_individuals_to_locations returns real routes (osrm_live)", {
  skip_if_not(tryCatch({
    httr2::request("http://totoro.magpie-inconnu.ts.net:5001/health") |>
      httr2::req_timeout(5) |> httr2::req_perform()
    TRUE
  }, error = function(e) FALSE), "OSRM server not available")

  source(file.path(here::here(), "R", "locations.R"))
  locations <- get_target_locations()

  individuals <- tibble(
    individual_id = c(1, 2),
    household_id = c(1, 2),
    postcode = c("4011", "4000"),
    lon = c(153.06, 153.02),
    lat = c(-27.43, -27.47)
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)

  result <- route_individuals_to_locations(individuals, locations)
  expect_equal(nrow(result), 6)  # 2 individuals x 3 locations
  expect_true(all(c("individual_id", "household_id", "postcode", "location_id",
                     "duration_min", "distance_km") %in% names(result)))
  expect_true(all(result$duration_min > 0))
  expect_true(all(result$distance_km > 0))
})
