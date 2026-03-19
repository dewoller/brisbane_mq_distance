# ABOUTME: Visualization functions for geocoded address-level travel analysis
# ABOUTME: Produces violin plots, individual point maps, combined summary table, and zoom heatmaps

library(ggplot2)
library(dplyr)
library(sf)
library(leaflet)
library(gt)
library(htmlwidgets)

make_geo_violin <- function(routes, locations, output_path) {
  loc_info <- locations |> st_drop_geometry() |> select(location_id, name, role)
  loc_colors <- setNames(location_colors(locations), paste0(loc_info$name, "\n(", loc_info$role, ")"))

  plot_data <- routes |>
    left_join(loc_info, by = "location_id") |>
    mutate(label = paste0(name, "\n(", role, ")") |> factor())

  p <- ggplot(plot_data, aes(x = label, y = duration_min)) +
    geom_violin(aes(fill = label), alpha = 0.7, scale = "width") +
    geom_boxplot(width = 0.15, outlier.shape = NA, alpha = 0.5) +
    scale_fill_manual(values = loc_colors) +
    labs(
      title = "Travel Time Distribution to Each Location",
      subtitle = "Based on geocoded individual addresses",
      x = NULL,
      y = "Driving Time (minutes)"
    ) +
    theme_minimal(base_size = 14) +
    theme(legend.position = "none") +
    coord_cartesian(ylim = c(0, quantile(plot_data$duration_min, 0.98)))

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  ggsave(output_path, p, width = 10, height = 7, dpi = 150)
  output_path
}

make_geo_point_map <- function(individuals_sf, routes, locations, output_path) {
  loc_info <- locations |> st_drop_geometry() |> select(location_id, name)

  # Find best (shortest) travel time per individual across locations
  best_times <- routes |>
    group_by(individual_id) |>
    summarise(
      best_duration = min(duration_min, na.rm = TRUE),
      best_location = location_id[which.min(duration_min)],
      .groups = "drop"
    )

  ind_data <- individuals_sf |>
    mutate(
      ind_lon = st_coordinates(geometry)[, 1],
      ind_lat = st_coordinates(geometry)[, 2]
    ) |>
    st_drop_geometry() |>
    left_join(best_times, by = "individual_id") |>
    left_join(loc_info, by = c("best_location" = "location_id"))

  pal <- colorNumeric(palette = "YlOrRd", domain = ind_data$best_duration, na.color = "#cccccc")

  loc_data <- locations |>
    mutate(
      coords = st_coordinates(geometry) |> as_tibble(),
      lon = coords$X,
      lat = coords$Y,
      popup = paste0("<strong>", name, "</strong><br/>", address, "<br/>Role: ", role)
    ) |>
    st_drop_geometry()
  loc_cols <- location_colors(locations)

  m <- leaflet() |>
    addProviderTiles(providers$CartoDB.Positron) |>
    addCircleMarkers(
      lng = ind_data$ind_lon, lat = ind_data$ind_lat,
      radius = 5,
      color = pal(ind_data$best_duration),
      fillColor = pal(ind_data$best_duration),
      fillOpacity = 0.7,
      popup = paste0(
        "ID: ", ind_data$individual_id, "<br/>",
        "Postcode: ", ind_data$postcode, "<br/>",
        "Best: ", ind_data$name, " (", round(ind_data$best_duration, 1), " min)"
      )
    ) |>
    addCircleMarkers(
      lng = loc_data$lon, lat = loc_data$lat,
      radius = 12, color = loc_cols, fillColor = loc_cols, fillOpacity = 1,
      popup = loc_data$popup
    ) |>
    addLegend(
      position = "bottomright", pal = pal, values = ind_data$best_duration,
      title = "Travel Time (min)<br/>to nearest location"
    ) |>
    addLegend(
      position = "bottomleft", colors = loc_cols,
      labels = paste0(loc_data$name, " (", loc_data$role, ")"),
      title = "Locations"
    )

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  saveWidget(m, file = normalizePath(output_path, mustWork = FALSE), selfcontained = TRUE)
  output_path
}

make_geo_summary_table <- function(community_stats, families_stats, locations) {
  loc_info <- locations |> st_drop_geometry() |> select(location_id, name, address, role)

  format_stats <- function(stats, population_label) {
    stats |>
      left_join(loc_info, by = "location_id") |>
      mutate(Population = population_label)
  }

  combined <- bind_rows(
    format_stats(community_stats, "Community"),
    format_stats(families_stats, "Families")
  ) |>
    select(
      Population,
      Location = name,
      Role = role,
      Individuals = n_individuals,
      Households = n_households,
      `Mean Distance (km)` = mean_distance_km,
      `Mean Time (min)` = mean_duration_min,
      `Median Time (min)` = median_duration_min,
      `P25 (min)` = p25_duration_min,
      `P75 (min)` = p75_duration_min,
      `<=15 min (%)` = pct_within_15min,
      `<=30 min (%)` = pct_within_30min,
      `<=45 min (%)` = pct_within_45min,
      `<=60 min (%)` = pct_within_60min
    )

  tbl <- combined |>
    gt(groupname_col = "Population") |>
    tab_header(
      title = "Location Accessibility Comparison",
      subtitle = "Based on geocoded individual addresses"
    ) |>
    fmt_number(columns = where(is.numeric), decimals = 1) |>
    fmt_number(columns = c("Individuals", "Households"), decimals = 0)

  out_path <- "output/geo_summary_table.html"
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  gtsave(tbl, out_path)
  out_path
}

make_zoom_map <- function(zoom_result, locations, output_path) {
  loc_data <- locations |>
    mutate(
      coords = st_coordinates(geometry) |> as_tibble(),
      lon = coords$X,
      lat = coords$Y,
      popup = paste0("<strong>", name, "</strong><br/>", address, "<br/>Role: ", role)
    ) |>
    st_drop_geometry()
  loc_cols <- location_colors(locations)

  # Load boundaries to join geometry back to results (SA2, SA1, and all MB)
  sa2_boundaries <- load_sa_boundaries("data/abs", "SA2")
  sa1_boundaries <- load_sa_boundaries("data/abs", "SA1")
  mb_boundaries <- load_mb_boundaries_all("data/abs")

  sa2_code_col <- grep("SA2_CODE", names(sa2_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa1_code_col <- grep("SA1_CODE", names(sa1_boundaries), value = TRUE, ignore.case = TRUE)[1]
  mb_code_col <- grep("MB_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  join_results <- function(boundaries, code_col, results) {
    boundaries |>
      mutate(area_code = as.character(!!sym(code_col))) |>
      inner_join(results |> mutate(area_code = as.character(area_code)), by = "area_code")
  }

  sa2_sf <- join_results(sa2_boundaries, sa2_code_col, zoom_result$sa2)
  sa1_sf <- join_results(sa1_boundaries, sa1_code_col, zoom_result$sa1)
  mb_sf <- join_results(mb_boundaries, mb_code_col, zoom_result$mb)

  # Per-level palettes
  pal_sa2 <- colorNumeric(palette = "YlOrRd", domain = sa2_sf$mean_duration_min, na.color = "#ccc")
  pal_sa1 <- colorNumeric(palette = "YlOrRd", domain = sa1_sf$mean_duration_min, na.color = "#ccc")
  pal_mb  <- colorNumeric(palette = "YlOrRd", domain = mb_sf$mean_duration_min, na.color = "#ccc")

  make_popup <- function(code, dur) {
    paste0("Area: ", code, "<br/>Mean travel: ", round(dur, 1), " min")
  }

  m <- leaflet() |>
    addProviderTiles(providers$CartoDB.Positron) |>
    addPolygons(data = sa2_sf, fillColor = ~pal_sa2(mean_duration_min), fillOpacity = 0.4,
                weight = 1, color = "#333", group = "SA2",
                popup = ~make_popup(area_code, mean_duration_min)) |>
    addPolygons(data = sa1_sf, fillColor = ~pal_sa1(mean_duration_min), fillOpacity = 0.5,
                weight = 1, color = "#555", group = "SA1",
                popup = ~make_popup(area_code, mean_duration_min)) |>
    addPolygons(data = mb_sf, fillColor = ~pal_mb(mean_duration_min), fillOpacity = 0.7,
                weight = 1, color = "#999", group = "Mesh Blocks",
                popup = ~make_popup(area_code, mean_duration_min)) |>
    addCircleMarkers(
      lng = loc_data$lon, lat = loc_data$lat,
      radius = 10, color = loc_cols, fillColor = loc_cols, fillOpacity = 1,
      popup = loc_data$popup, group = "Existing Locations"
    ) |>
    addLayersControl(
      overlayGroups = c("SA2", "SA1", "Mesh Blocks", "Existing Locations"),
      options = layersControlOptions(collapsed = FALSE)
    ) |>
    hideGroup(c("SA2", "SA1")) |>
    addLegend(position = "bottomright", pal = pal_mb, values = mb_sf$mean_duration_min,
              title = "Mesh Block<br/>Mean Travel (min)")

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  saveWidget(m, file = normalizePath(output_path, mustWork = FALSE), selfcontained = TRUE)
  output_path
}
