# ABOUTME: Tests for household classification into family/non-family
# ABOUTME: Validates 3+ people threshold and correct column additions

library(testthat)
library(tibble)
library(dplyr)
library(sf)
source(file.path(here::here(), "R", "family.R"))

test_that("classify_households adds household_size and is_family columns", {
  # 3 in household 1 (family), 2 in household 2 (not family), 1 in household 3 (not family)
  individuals <- tibble(
    individual_id = 1:6,
    household_id = c(1, 1, 1, 2, 2, 3),
    postcode = rep("4000", 6),
    lon = 153.0,
    lat = -27.5
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)

  result <- classify_households(individuals)
  expect_true("household_size" %in% names(result))
  expect_true("is_family" %in% names(result))

  # Household 1 has 3 people → family
  h1 <- result |> filter(household_id == 1)
  expect_equal(unique(h1$household_size), 3)
  expect_true(all(h1$is_family))

  # Household 2 has 2 people → not family
  h2 <- result |> filter(household_id == 2)
  expect_equal(unique(h2$household_size), 2)
  expect_false(any(h2$is_family))

  # Household 3 has 1 person → not family
  h3 <- result |> filter(household_id == 3)
  expect_equal(unique(h3$household_size), 1)
  expect_false(any(h3$is_family))
})
