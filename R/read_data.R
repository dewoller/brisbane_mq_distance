# ABOUTME: Functions to read and summarise the Brisbane Family Excel data
# ABOUTME: Cleans column names and aggregates individual/household counts per postcode

library(readxl)
library(dplyr)

read_excel_data <- function(path) {
  raw <- read_excel(path, sheet = "Sheet1")
  raw |>
    rename(
      individual_id = 1,
      household_id = 2,
      postcode = 3
    ) |>
    mutate(postcode = as.character(as.integer(postcode))) |>
    filter(!is.na(postcode))
}

summarise_postcodes <- function(df) {
  df |>
    group_by(postcode) |>
    summarise(
      n_individuals = n(),
      n_households = n_distinct(household_id),
      .groups = "drop"
    ) |>
    mutate(avg_household_size = n_individuals / n_households)
}
