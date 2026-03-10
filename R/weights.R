# ABOUTME: Spreads postcode-level individual/household counts across mesh blocks
# ABOUTME: Uses mesh block population as a proportional distribution key

library(dplyr)
library(sf)

spread_weights <- function(mb_postcode_map, filtered_postcodes) {
  mb_postcode_map |>
    filter(postcode %in% filtered_postcodes$postcode) |>
    group_by(postcode) |>
    mutate(
      postcode_total_pop = sum(population),
      pop_share = population / postcode_total_pop
    ) |>
    ungroup() |>
    inner_join(
      filtered_postcodes |> select(postcode, n_individuals, n_households),
      by = "postcode"
    ) |>
    mutate(
      spread_individuals = n_individuals * pop_share,
      spread_households = n_households * pop_share
    ) |>
    select(mb_code, postcode, population, pop_share,
           centroid_lon, centroid_lat,
           spread_individuals, spread_households)
}
