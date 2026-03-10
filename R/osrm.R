# ABOUTME: OSRM table API client for batch driving distance/duration queries
# ABOUTME: Chunks mesh block centroids into batches and queries against louisa_ts:5000

library(httr2)
library(dplyr)
library(tidyr)
library(purrr)
library(tibble)

build_osrm_table_url <- function(sources, destinations, base_url = "http://louisa_ts:5000") {
  # Combine all coordinates: sources first, then destinations
  all_coords <- c(
    paste(sources$lon, sources$lat, sep = ","),
    paste(destinations$lon, destinations$lat, sep = ",")
  )
  coords_str <- paste(all_coords, collapse = ";")

  n_src <- nrow(sources)
  n_dst <- nrow(destinations)
  src_indices <- paste(seq(0, n_src - 1), collapse = ";")
  dst_indices <- paste(seq(n_src, n_src + n_dst - 1), collapse = ";")

  paste0(
    base_url, "/table/v1/driving/", coords_str,
    "?sources=", src_indices,
    "&destinations=", dst_indices,
    "&annotations=duration,distance"
  )
}

parse_osrm_table_response <- function(response, mb_codes, location_ids) {
  # Convert duration matrix to long-format tibble via pivot
  # Handle both matrix (test) and list-of-lists (JSON) input
  dur_mat <- if (is.matrix(response$durations)) {
    response$durations
  } else {
    do.call(rbind, response$durations)
  }
  dist_mat <- if (is.matrix(response$distances)) {
    response$distances
  } else {
    do.call(rbind, response$distances)
  }

  dur_mat |>
    as_tibble(.name_repair = ~location_ids) |>
    mutate(mb_code = mb_codes) |>
    pivot_longer(-mb_code, names_to = "location_id", values_to = "duration_sec") |>
    # Join distance matrix the same way
    inner_join(
      dist_mat |>
        as_tibble(.name_repair = ~location_ids) |>
        mutate(mb_code = mb_codes) |>
        pivot_longer(-mb_code, names_to = "location_id", values_to = "distance_m"),
      by = c("mb_code", "location_id")
    )
}

chunk_indices <- function(n, chunk_size = 100) {
  starts <- seq(1, n, by = chunk_size)
  lapply(starts, function(s) s:min(s + chunk_size - 1, n))
}

route_all_mb_to_locations <- function(mb_weights, locations, osrm_url = "http://louisa_ts:5000", chunk_size = 100) {
  mb_data <- mb_weights |>
    sf::st_drop_geometry() |>
    select(mb_code, postcode, centroid_lon, centroid_lat, spread_individuals, spread_households)

  loc_destinations <- locations |>
    sf::st_coordinates() |>
    as_tibble() |>
    rename(lon = X, lat = Y)

  loc_ids <- locations$location_id

  message("Routing ", nrow(mb_data), " mesh blocks x ", nrow(loc_destinations), " locations")

  # Chunk, query OSRM, parse, and bind in a single pipeline
  chunk_indices(nrow(mb_data), chunk_size) |>
    map(function(idx) {
      chunk <- mb_data |> slice(idx)

      chunk |>
        select(lon = centroid_lon, lat = centroid_lat) |>
        build_osrm_table_url(loc_destinations, base_url = osrm_url) |>
        request() |>
        req_timeout(120) |>
        req_retry(max_tries = 3, backoff = ~ 2) |>
        req_perform() |>
        resp_body_json() |>
        (\(resp) {
          if (resp$code != "Ok") { warning("OSRM error: ", resp$code); return(NULL) }
          parse_osrm_table_response(resp, chunk$mb_code, loc_ids)
        })() |>
        left_join(
          chunk |> select(mb_code, postcode, spread_individuals, spread_households),
          by = "mb_code"
        )
    }, .progress = TRUE) |>
    bind_rows() |>
    mutate(
      distance_km = distance_m / 1000,
      duration_min = duration_sec / 60
    )
}
