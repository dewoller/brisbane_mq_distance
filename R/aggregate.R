# ABOUTME: Aggregates mesh-block-level OSRM routes to postcode x location statistics
# ABOUTME: Computes weighted means, min/max, percentiles, and time-band breakdowns

library(dplyr)
library(tidyr)

aggregate_postcode_location <- function(mb_routes) {
  mb_routes |>
    group_by(postcode, location_id) |>
    summarise(
      n_individuals = sum(spread_individuals),
      n_households = sum(spread_households),
      weighted_mean_distance_km = weighted.mean(distance_km, spread_individuals),
      weighted_mean_duration_min = weighted.mean(duration_min, spread_individuals),
      min_mb_distance_km = min(distance_km),
      max_mb_distance_km = max(distance_km),
      min_mb_duration_min = min(duration_min),
      max_mb_duration_min = max(duration_min),
      .groups = "drop"
    )
}

summarise_locations <- function(postcode_location_stats) {
  # Expand postcode-level rows to individual-weighted rows for percentile calcs
  expanded <- postcode_location_stats |>
    mutate(weight = pmax(1, round(n_individuals))) |>
    uncount(weight, .remove = FALSE)

  # Calculate percentiles per location from expanded data
  percentiles <- expanded |>
    group_by(location_id) |>
    summarise(
      weighted_median_duration_min = median(weighted_mean_duration_min),
      p25_duration_min = quantile(weighted_mean_duration_min, 0.25, names = FALSE),
      p75_duration_min = quantile(weighted_mean_duration_min, 0.75, names = FALSE),
      .groups = "drop"
    )

  # Calculate weighted means and time-band percentages
  postcode_location_stats |>
    group_by(location_id) |>
    summarise(
      total_individuals = sum(n_individuals),
      total_households = sum(n_households),
      weighted_mean_distance_km = weighted.mean(weighted_mean_distance_km, n_individuals),
      weighted_mean_duration_min = weighted.mean(weighted_mean_duration_min, n_individuals),
      pct_within_15min = sum(n_individuals[weighted_mean_duration_min <= 15]) / sum(n_individuals) * 100,
      pct_within_30min = sum(n_individuals[weighted_mean_duration_min <= 30]) / sum(n_individuals) * 100,
      pct_within_45min = sum(n_individuals[weighted_mean_duration_min <= 45]) / sum(n_individuals) * 100,
      pct_within_60min = sum(n_individuals[weighted_mean_duration_min <= 60]) / sum(n_individuals) * 100,
      .groups = "drop"
    ) |>
    inner_join(percentiles, by = "location_id")
}

build_full_matrix <- function(postcode_location_stats, filtered_postcodes) {
  # Only join columns from filtered_postcodes that aren't already present
  existing_cols <- names(postcode_location_stats)
  metadata_cols <- setdiff(names(filtered_postcodes), existing_cols)
  join_cols <- c("postcode", metadata_cols)

  postcode_location_stats |>
    left_join(
      filtered_postcodes |> select(all_of(join_cols)),
      by = "postcode"
    )
}

write_csv_output <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(data, path)
  path
}
