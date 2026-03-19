# ABOUTME: Aggregates geocoded individual-level routes to location-level statistics
# ABOUTME: Computes simple means, percentiles, and time-band percentages (no weighting needed)

library(dplyr)

aggregate_geo_location <- function(routes) {
  routes |>
    group_by(location_id) |>
    summarise(
      n_individuals = n_distinct(individual_id),
      n_households = n_distinct(household_id),
      mean_distance_km = mean(distance_km, na.rm = TRUE),
      mean_duration_min = mean(duration_min, na.rm = TRUE),
      median_duration_min = median(duration_min, na.rm = TRUE),
      p25_duration_min = quantile(duration_min, 0.25, names = FALSE, na.rm = TRUE),
      p75_duration_min = quantile(duration_min, 0.75, names = FALSE, na.rm = TRUE),
      pct_within_15min = sum(duration_min <= 15) / n() * 100,
      pct_within_30min = sum(duration_min <= 30) / n() * 100,
      pct_within_45min = sum(duration_min <= 45) / n() * 100,
      pct_within_60min = sum(duration_min <= 60) / n() * 100,
      .groups = "drop"
    )
}

build_geo_full_matrix <- function(routes) {
  routes |>
    select(individual_id, household_id, postcode, location_id, duration_min, distance_km)
}
