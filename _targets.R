# ABOUTME: targets pipeline for Ali Brisbane travel distance analysis
# ABOUTME: Calculates OSRM driving distances from client postcodes to 3 candidate locations

library(targets)

tar_source()

list(
  # --- Data reading ---
  tar_target(raw_data, read_excel_data("data/brisbane_family.xlsx")),
  tar_target(postcode_summary, summarise_postcodes(raw_data)),

  # --- ABS spatial data ---
  tar_target(mb_boundaries, load_mb_boundaries("data/abs")),
  tar_target(poa_boundaries, load_poa_boundaries("data/abs")),
  tar_target(mb_allocation, load_mb_allocation("data/abs")),
  tar_target(mb_population, load_mb_population("data/abs")),

  # --- Mesh block mapping ---
  tar_target(mb_postcode_map, build_mb_postcode_map(mb_boundaries, mb_allocation, mb_population, postcode_summary)),
  tar_target(outlier_result, filter_outlier_postcodes(postcode_summary, poa_boundaries)),
  tar_target(filtered_postcodes, outlier_result$filtered_summary),

  # --- Weights ---
  tar_target(mb_weights, spread_weights(mb_postcode_map, filtered_postcodes)),

  # --- Locations ---
  tar_target(locations, get_target_locations()),

  # --- OSRM routing ---
  tar_target(mb_routes, route_all_mb_to_locations(mb_weights, locations)),

  # --- Aggregation ---
  tar_target(postcode_location_stats, aggregate_postcode_location(mb_routes)),
  tar_target(location_summary, summarise_locations(postcode_location_stats)),
  tar_target(full_matrix, build_full_matrix(postcode_location_stats, filtered_postcodes)),

  # --- CSV exports ---
  tar_target(matrix_csv, write_csv_output(full_matrix, "output/full_matrix.csv"), format = "file"),
  tar_target(summary_csv, write_csv_output(location_summary, "output/summary_table.csv"), format = "file"),

  # --- Visualization ---
  tar_target(violin_plot, make_violin_plots(mb_routes, locations), format = "file"),
  tar_target(map_html, make_map(poa_boundaries, postcode_location_stats, locations, filtered_postcodes), format = "file"),
  tar_target(summary_table_gt, make_summary_table_gt(location_summary, locations), format = "file")
)
