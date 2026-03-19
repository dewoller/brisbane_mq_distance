# ABOUTME: Classifies households by size and identifies family households (3+ people)
# ABOUTME: Adds household_size and is_family columns to individual-level data

library(dplyr)

classify_households <- function(geo_individuals) {
  household_sizes <- geo_individuals |>
    sf::st_drop_geometry() |>
    count(household_id, name = "household_size")

  geo_individuals |>
    left_join(household_sizes, by = "household_id") |>
    mutate(is_family = household_size >= 3)
}
