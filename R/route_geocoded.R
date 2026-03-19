# ABOUTME: Routes geocoded individuals to target locations via OSRM table API
# ABOUTME: Reuses build_osrm_table_url and parse_osrm_table_response from osrm.R

library(dplyr)
library(purrr)
library(sf)
library(httr2)
library(tibble)

route_individuals_to_locations <- function(individuals_sf, locations,
                                           osrm_url = "http://totoro.magpie-inconnu.ts.net:5001",
                                           chunk_size = 100) {
  ind_data <- individuals_sf |>
    mutate(
      ind_lon = st_coordinates(geometry)[, 1],
      ind_lat = st_coordinates(geometry)[, 2]
    ) |>
    st_drop_geometry() |>
    mutate(individual_id = as.character(individual_id))

  loc_destinations <- locations |>
    st_coordinates() |>
    as_tibble() |>
    rename(lon = X, lat = Y)

  loc_ids <- locations$location_id

  message("Routing ", nrow(ind_data), " individuals x ", nrow(loc_destinations), " locations")

  chunk_indices(nrow(ind_data), chunk_size) |>
    map(function(idx) {
      chunk <- ind_data |> slice(idx)

      chunk |>
        select(lon = ind_lon, lat = ind_lat) |>
        build_osrm_table_url(loc_destinations, base_url = osrm_url) |>
        request() |>
        req_timeout(120) |>
        req_retry(max_tries = 3, backoff = ~ 2) |>
        req_perform() |>
        resp_body_json() |>
        (\(resp) {
          if (resp$code != "Ok") { warning("OSRM error: ", resp$code); return(NULL) }
          parse_osrm_table_response(resp, chunk$individual_id, loc_ids)
        })() |>
        rename(individual_id = mb_code) |>
        left_join(
          chunk |> select(individual_id, household_id, postcode),
          by = "individual_id"
        )
    }, .progress = TRUE) |>
    bind_rows() |>
    mutate(
      individual_id = as.double(individual_id),
      distance_km = distance_m / 1000,
      duration_min = duration_sec / 60
    )
}
