# ABOUTME: Tests for geocoded visualization functions
# ABOUTME: Validates that violin plots, point maps, summary tables, and zoom maps produce output files

library(testthat)
library(tibble)
library(dplyr)
library(sf)
source(file.path(here::here(), "R", "visualize_geocoded.R"))
source(file.path(here::here(), "R", "locations.R"))
source(file.path(here::here(), "R", "visualize.R"))

test_that("make_geo_violin creates a PNG file", {
  locations <- get_target_locations()

  routes <- tibble(
    individual_id = rep(1:10, 3),
    household_id = rep(c(1,1,2,2,3,3,4,4,5,5), 3),
    postcode = rep("4000", 30),
    location_id = rep(c("loc_1", "loc_2", "loc_3"), each = 10),
    duration_min = runif(30, 5, 60),
    distance_km = runif(30, 2, 40),
    duration_sec = duration_min * 60,
    distance_m = distance_km * 1000
  )

  withr::with_tempdir({
    dir.create("output", showWarnings = FALSE)
    result <- make_geo_violin(routes, locations, "output/test_violin.png")
    expect_true(file.exists(result))
    expect_true(file.size(result) > 0)
  })
})

test_that("make_geo_point_map creates an HTML file", {
  locations <- get_target_locations()

  individuals <- tibble(
    individual_id = 1:5,
    household_id = c(1, 1, 2, 2, 3),
    postcode = rep("4000", 5),
    lon = c(153.02, 153.03, 153.04, 153.05, 153.06),
    lat = c(-27.47, -27.46, -27.45, -27.44, -27.43)
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)

  routes <- tibble(
    individual_id = rep(1:5, 3),
    household_id = rep(c(1,1,2,2,3), 3),
    postcode = rep("4000", 15),
    location_id = rep(c("loc_1","loc_2","loc_3"), each = 5),
    duration_min = runif(15, 5, 60),
    distance_km = runif(15, 2, 40)
  )

  withr::with_tempdir({
    dir.create("output", showWarnings = FALSE)
    result <- make_geo_point_map(individuals, routes, locations, "output/test_map.html")
    expect_true(file.exists(result))
  })
})
