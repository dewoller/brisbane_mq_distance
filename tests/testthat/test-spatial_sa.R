# ABOUTME: Tests for SA-level boundary loading from ABS shapefiles
# ABOUTME: Validates that load_sa_boundaries returns sf objects for SA1, SA2, SA3

library(testthat)
library(sf)
source(file.path(here::here(), "R", "spatial.R"))

test_that("load_sa_boundaries returns sf for SA3 filtered to QLD", {
  result <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA3")
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  # Should have an SA3 code column
  sa3_col <- grep("SA3_CODE", names(result), value = TRUE, ignore.case = TRUE)
  expect_length(sa3_col, 1)
  # Should have centroid columns
  expect_true(all(c("centroid_lon", "centroid_lat") %in% names(result)))
})

test_that("load_sa_boundaries returns sf for SA2 filtered to QLD", {
  result <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA2")
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  sa2_col <- grep("SA2_CODE", names(result), value = TRUE, ignore.case = TRUE)
  expect_length(sa2_col, 1)
})

test_that("load_sa_boundaries returns sf for SA1 filtered to QLD", {
  result <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA1")
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  sa1_col <- grep("SA1_CODE", names(result), value = TRUE, ignore.case = TRUE)
  expect_length(sa1_col, 1)
})

test_that("load_sa_boundaries rejects invalid level", {
  expect_error(load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA4"))
})
