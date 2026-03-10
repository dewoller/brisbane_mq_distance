# ABOUTME: Tests for population-proportional weight spreading
# ABOUTME: Validates that individual/household counts distribute correctly across mesh blocks

library(testthat)
library(tibble)
library(dplyr)
library(sf)

source(file.path(here::here(), "R", "weights.R"))

test_that("spread_weights distributes individuals proportionally by MB population", {
  # Postcode 4000 has 10 individuals, 2 MBs with populations 100 and 300
  mb_map <- st_sf(
    mb_code = c("MB_A", "MB_B"),
    postcode = c("4000", "4000"),
    population = c(100, 300),
    centroid_lon = c(153.0, 153.01),
    centroid_lat = c(-27.5, -27.51),
    geometry = st_sfc(st_point(c(153.0, -27.5)), st_point(c(153.01, -27.51))),
    crs = 4326
  )
  pc_summary <- tibble(
    postcode = "4000",
    n_individuals = 10,
    n_households = 3,
    avg_household_size = 10 / 3
  )

  result <- spread_weights(mb_map, pc_summary)

  expect_equal(nrow(result), 2)
  expect_equal(result$spread_individuals[result$mb_code == "MB_A"], 10 * 100 / 400)
  expect_equal(result$spread_individuals[result$mb_code == "MB_B"], 10 * 300 / 400)
  expect_equal(sum(result$spread_individuals), 10)
  expect_equal(sum(result$spread_households), 3)
})

test_that("spread_weights handles postcode with single MB", {
  mb_map <- st_sf(
    mb_code = "MB_ONLY",
    postcode = "4001",
    population = 500,
    centroid_lon = 153.0,
    centroid_lat = -27.5,
    geometry = st_sfc(st_point(c(153.0, -27.5))),
    crs = 4326
  )
  pc_summary <- tibble(postcode = "4001", n_individuals = 7, n_households = 2, avg_household_size = 3.5)

  result <- spread_weights(mb_map, pc_summary)
  expect_equal(result$spread_individuals, 7)
  expect_equal(result$spread_households, 2)
})

test_that("spread_weights only includes postcodes in filtered summary", {
  mb_map <- st_sf(
    mb_code = c("MB_A", "MB_B"),
    postcode = c("4000", "4999"),
    population = c(100, 200),
    centroid_lon = c(153.0, 145.0),
    centroid_lat = c(-27.5, -16.9),
    geometry = st_sfc(st_point(c(153.0, -27.5)), st_point(c(145.0, -16.9))),
    crs = 4326
  )
  pc_summary <- tibble(postcode = "4000", n_individuals = 10, n_households = 3, avg_household_size = 10/3)

  result <- spread_weights(mb_map, pc_summary)
  expect_equal(nrow(result), 1)
  expect_equal(result$postcode, "4000")
})
