# ABOUTME: Visualization functions for travel analysis results
# ABOUTME: Produces violin plots (ggplot2), leaflet map, and gt summary table

library(ggplot2)
library(dplyr)
library(sf)
library(leaflet)
library(gt)
library(RColorBrewer)
library(htmlwidgets)

make_violin_plots <- function(mb_routes, locations) {
  plot_data <- mb_routes |>
    left_join(
      locations |> st_drop_geometry() |> select(location_id, name, role),
      by = "location_id"
    ) |>
    mutate(label = paste0(name, "\n(", role, ")") |> factor())

  p <- ggplot(plot_data, aes(x = label, y = duration_min, weight = spread_individuals)) +
    geom_violin(aes(fill = label), alpha = 0.7, scale = "width") +
    geom_boxplot(width = 0.15, outlier.shape = NA, alpha = 0.5) +
    scale_fill_brewer(palette = "Set2") +
    labs(
      title = "Travel Time Distribution to Each Location",
      subtitle = "Weighted by client population spread across mesh blocks",
      x = NULL,
      y = "Driving Time (minutes)"
    ) +
    theme_minimal(base_size = 14) +
    theme(legend.position = "none") +
    coord_cartesian(ylim = c(0, quantile(plot_data$duration_min, 0.98)))

  out_path <- "output/violin_plots.png"
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  ggsave(out_path, p, width = 10, height = 7, dpi = 150)
  out_path
}

make_map <- function(poa_boundaries, postcode_location_stats, locations, filtered_postcodes) {
  # Prepare POA polygons with stats for the nearest location
  poa_code_col <- grep("POA_CODE", names(poa_boundaries), value = TRUE, ignore.case = TRUE)[1]
  poa <- poa_boundaries |>
    rename(postcode = !!sym(poa_code_col)) |>
    mutate(postcode = as.character(postcode)) |>
    filter(postcode %in% filtered_postcodes$postcode)

  # Join location names for readable popups
  loc_names <- locations |>
    st_drop_geometry() |>
    select(location_id, name)

  # Build popup showing ALL 3 locations per postcode
  all_stats <- postcode_location_stats |>
    left_join(loc_names, by = "location_id")

  popup_df <- all_stats |>
    arrange(postcode, weighted_mean_duration_min) |>
    group_by(postcode) |>
    summarise(
      n_individuals = first(n_individuals),
      best_duration = min(weighted_mean_duration_min),
      popup_detail = paste0(
        name, ": ", round(weighted_mean_duration_min, 1), " min (",
        round(weighted_mean_distance_km, 1), " km)"
      ) |> paste(collapse = "<br/>"),
      .groups = "drop"
    ) |>
    mutate(popup = paste0(
      "<strong>Postcode: ", postcode, "</strong><br/>",
      "Individuals: ", round(n_individuals), "<br/><br/>",
      popup_detail
    ))

  poa_with_stats <- poa |>
    left_join(popup_df, by = "postcode")

  # Colour palette based on best travel time
  pal <- colorNumeric(
    palette = "YlOrRd",
    domain = poa_with_stats$best_duration,
    na.color = "#cccccc"
  )

  # Build location data for markers
  loc_data <- locations |>
    mutate(
      coords = st_coordinates(geometry) |> as_tibble(),
      lon = coords$X,
      lat = coords$Y,
      popup = paste0("<strong>", name, "</strong><br/>", address, "<br/>Role: ", role)
    ) |>
    st_drop_geometry()

  m <- leaflet() |>
    addTiles() |>
    addPolygons(
      data = poa_with_stats,
      fillColor = ~pal(best_duration),
      fillOpacity = 0.6,
      weight = 1,
      color = "#333",
      popup = ~popup
    ) |>
    addCircleMarkers(
      lng = loc_data$lon, lat = loc_data$lat,
      radius = 10,
      color = c("#e41a1c", "#377eb8", "#4daf4a"),
      fillOpacity = 1,
      popup = loc_data$popup
    ) |>
    addLegend(
      position = "bottomright",
      pal = pal,
      values = poa_with_stats$best_duration,
      title = "Travel Time (min)<br/>to nearest location"
    )

  out_path <- "output/map.html"
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  saveWidget(m, file = normalizePath(out_path, mustWork = FALSE), selfcontained = TRUE)
  out_path
}

make_summary_table_gt <- function(location_summary, locations) {
  tbl_data <- location_summary |>
    left_join(
      locations |> st_drop_geometry() |> select(location_id, name, address, role),
      by = "location_id"
    ) |>
    select(
      Location = name,
      Address = address,
      Role = role,
      Individuals = total_individuals,
      Households = total_households,
      `Mean Distance (km)` = weighted_mean_distance_km,
      `Mean Time (min)` = weighted_mean_duration_min,
      `Median Time (min)` = weighted_median_duration_min,
      `P25 (min)` = p25_duration_min,
      `P75 (min)` = p75_duration_min,
      `<=15 min (%)` = pct_within_15min,
      `<=30 min (%)` = pct_within_30min,
      `<=45 min (%)` = pct_within_45min,
      `<=60 min (%)` = pct_within_60min
    )

  tbl <- tbl_data |>
    gt() |>
    tab_header(
      title = "Location Accessibility Comparison",
      subtitle = "Weighted by client population distributed across mesh blocks"
    ) |>
    fmt_number(columns = where(is.numeric), decimals = 1) |>
    fmt_number(columns = c("Individuals", "Households"), decimals = 0)

  out_path <- "output/summary_table.html"
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  gtsave(tbl, out_path)
  out_path
}
