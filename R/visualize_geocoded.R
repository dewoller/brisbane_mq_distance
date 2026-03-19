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
    addTiles() |>
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
