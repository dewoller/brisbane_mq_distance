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

  # --- Optimal location analysis ---
  tar_target(candidate_locations, build_candidate_locations(poa_boundaries, filtered_postcodes)),
  tar_target(candidate_routes, route_mb_to_candidates(mb_weights, candidate_locations)),
  tar_target(candidate_ranking, rank_candidate_locations(candidate_routes)),
  tar_target(candidate_comparison, compare_candidates_to_locations(candidate_ranking, mb_routes, locations)),

  # --- CSV exports ---
  tar_target(matrix_csv, write_csv_output(full_matrix, "output/full_matrix.csv"), format = "file"),
  tar_target(summary_csv, write_csv_output(location_summary, "output/summary_table.csv"), format = "file"),
  tar_target(ranking_csv, write_csv_output(candidate_ranking, "output/candidate_ranking.csv"), format = "file"),
  tar_target(comparison_csv, write_csv_output(candidate_comparison, "output/candidate_comparison.csv"), format = "file"),

  # --- Visualization ---
  tar_target(violin_plot, make_violin_plots(mb_routes, locations), format = "file"),
  tar_target(map_html, make_map(poa_boundaries, postcode_location_stats, locations, filtered_postcodes), format = "file"),
  tar_target(population_map_html, make_population_map(poa_boundaries, filtered_postcodes, locations), format = "file"),
  tar_target(summary_table_gt, make_summary_table_gt(location_summary, locations), format = "file"),

  # === Geocoded address-level analysis ===

  # --- Geocoding ---
  tar_target(geo_raw_data, read_geocoded_data("data/Brisbane Family data March 2026.xlsx")),
  tar_target(geo_address_lookup, geocode_addresses(geo_raw_data)),
  tar_target(geo_individuals_raw, assign_locations(geo_raw_data, geo_address_lookup, poa_boundaries)),
  tar_target(geo_individuals, filter_outlier_individuals(geo_individuals_raw, max_distance_km = 150)),

  # --- Family classification ---
  tar_target(geo_classified, classify_households(geo_individuals)),
  tar_target(geo_community, geo_classified),
  tar_target(geo_families, geo_classified |> dplyr::filter(is_family)),

  # --- Routing to 3 locations ---
  tar_target(geo_community_routes, route_individuals_to_locations(geo_community, locations)),
  tar_target(geo_families_routes, route_individuals_to_locations(geo_families, locations)),

  # --- Aggregation ---
  tar_target(geo_community_stats, aggregate_geo_location(geo_community_routes)),
  tar_target(geo_families_stats, aggregate_geo_location(geo_families_routes)),
  tar_target(geo_community_matrix, build_geo_full_matrix(geo_community_routes)),
  tar_target(geo_families_matrix, build_geo_full_matrix(geo_families_routes)),

  # --- All mesh blocks within 50km for optimal location ---
  tar_target(geo_mb_boundaries_all, load_mb_boundaries_all("data/abs")),
  tar_target(geo_community_zoom, route_all_mb_within_radius(geo_community, geo_mb_boundaries_all, radius_km = 50)),
  tar_target(geo_families_zoom, route_all_mb_within_radius(geo_families, geo_mb_boundaries_all, radius_km = 50)),

  # --- CSV exports ---
  tar_target(geo_community_stats_csv, write_csv_output(geo_community_stats, "output/geo_community_stats.csv"), format = "file"),
  tar_target(geo_families_stats_csv, write_csv_output(geo_families_stats, "output/geo_families_stats.csv"), format = "file"),
  tar_target(geo_community_matrix_csv, write_csv_output(geo_community_matrix, "output/geo_community_matrix.csv"), format = "file"),
  tar_target(geo_families_matrix_csv, write_csv_output(geo_families_matrix, "output/geo_families_matrix.csv"), format = "file"),
  tar_target(geo_community_zoom_csv, write_csv_output(geo_community_zoom$ranking, "output/geo_community_zoom_ranking.csv"), format = "file"),
  tar_target(geo_families_zoom_csv, write_csv_output(geo_families_zoom$ranking, "output/geo_families_zoom_ranking.csv"), format = "file"),

  # --- Visualization ---
  tar_target(geo_community_violin, make_geo_violin(geo_community_routes, locations, "output/geo_community_violin.png"), format = "file"),
  tar_target(geo_families_violin, make_geo_violin(geo_families_routes, locations, "output/geo_families_violin.png"), format = "file"),
  tar_target(geo_community_map, make_geo_point_map(geo_community, geo_community_routes, locations, "output/geo_community_map.html"), format = "file"),
  tar_target(geo_families_map, make_geo_point_map(geo_families, geo_families_routes, locations, "output/geo_families_map.html"), format = "file"),
  tar_target(geo_summary_table, make_geo_summary_table(geo_community_stats, geo_families_stats, locations), format = "file"),
  tar_target(geo_community_zoom_map, make_zoom_map(geo_community_zoom, locations, "output/geo_community_zoom_map.html"), format = "file"),
  tar_target(geo_families_zoom_map, make_zoom_map(geo_families_zoom, locations, "output/geo_families_zoom_map.html"), format = "file")
)
