# ABOUTME: Tests for Excel data reading and postcode summarisation
# ABOUTME: Validates data cleaning and aggregation logic

library(testthat)
source("../../R/read_data.R")

test_that("read_excel_data returns cleaned tibble", {
  # Use the real data file
  df <- read_excel_data("../../data/brisbane_family.xlsx")
  expect_s3_class(df, "tbl_df")
  expect_named(df, c("individual_id", "household_id", "postcode"))
  expect_type(df$individual_id, "double")
  expect_type(df$household_id, "double")
  expect_type(df$postcode, "character")
  expect_gt(nrow(df), 400)
})

test_that("summarise_postcodes counts correctly", {
  df <- tibble::tibble(
    individual_id = 1:7,
    household_id = c(1, 1, 1, 2, 2, 3, 3),
    postcode = c("4000", "4000", "4000", "4000", "4000", "4001", "4001")
  )
  result <- summarise_postcodes(df)
  expect_equal(nrow(result), 2)
  expect_equal(result$n_individuals[result$postcode == "4000"], 5)
  expect_equal(result$n_households[result$postcode == "4000"], 2)
  expect_equal(result$n_individuals[result$postcode == "4001"], 2)
  expect_equal(result$n_households[result$postcode == "4001"], 1)
  expect_equal(result$avg_household_size[result$postcode == "4000"], 5 / 2)
  expect_equal(result$avg_household_size[result$postcode == "4001"], 2 / 1)
})
