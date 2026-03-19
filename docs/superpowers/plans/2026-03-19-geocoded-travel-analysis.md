# Geocoded Address-Level Travel Analysis — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing R {targets} pipeline with geocoded address-level travel analysis for two populations (community and families), including progressive-zoom optimal location finding.

**Architecture:** New R files (`geocode.R`, `family.R`, `route_geocoded.R`, `aggregate_geocoded.R`, `zoom_candidates.R`, `visualize_geocoded.R`) with `geo_` prefixed targets appended to `_targets.R`. Existing pipeline untouched. Reuses `osrm.R` helpers and `locations.R` directly.

**Tech Stack:** R, {targets}, tidygeocoder (ArcGIS), sf, httr2, leaflet, ggplot2, gt, dplyr, tidyr, purrr

**Spec:** `docs/superpowers/specs/2026-03-19-geocoded-travel-analysis-design.md`

---

## Chunk 1: Data Ingestion, Geocoding, and Family Classification

### Task 1: Read new Excel data — `R/geocode.R` (read_geocoded_data)

**Files:**
- Create: `R/geocode.R`
- Create: `tests/testthat/test-geocode.R`

- [ ] **Step 1: Write the failing test for `read_geocoded_data`**

```r
# tests/testthat/test-geocode.R
# ABOUTME: Tests for geocoding functions — data reading, address geocoding, location assignment
# ABOUTME: Uses the real Brisbane Family data March 2026.xlsx for reading tests

library(testthat)
library(tibble)
library(dplyr)
source(file.path(here::here(), "R", "geocode.R"))

test_that("read_geocoded_data returns cleaned tibble with correct columns", {
  df <- read_geocoded_data(file.path(here::here(), "data", "Brisbane Family data March 2026.xlsx"))
  expect_s3_class(df, "tbl_df")
  expect_named(df, c("individual_id", "household_id", "address", "suburb", "state", "postcode"))
  expect_type(df$individual_id, "double")
  expect_type(df$household_id, "double")
  expect_type(df$postcode, "character")
  expect_equal(nrow(df), 425)
  # All postcodes should be present
  expect_true(all(!is.na(df$postcode)))
  # Should have some addresses (368 of 425)
  expect_gt(sum(!is.na(df$address)), 300)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-geocode.R")'`
Expected: FAIL — `read_geocoded_data` not found

- [ ] **Step 3: Write minimal implementation**

```r
# R/geocode.R
# ABOUTME: Reads new Brisbane Family Excel data and geocodes addresses via ArcGIS
# ABOUTME: Falls back to postcode centroid for missing/failed geocodes

library(readxl)
library(dplyr)
library(tidygeocoder)
library(sf)

read_geocoded_data <- function(path) {
  raw <- read_excel(path, sheet = "Raw Data")
  # Column names contain \r\n artifacts — select by position and rename
  col_names <- c("individual_id", "household_id", "address", "suburb", "state", "postcode")
  names(raw) <- col_names
  raw |>
    mutate(postcode = as.character(as.integer(postcode))) |>
    filter(!is.na(postcode))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-geocode.R")'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/geocode.R tests/testthat/test-geocode.R
git commit -m "feat: add read_geocoded_data for new Excel file"
```

---

### Task 2: Geocode addresses — `R/geocode.R` (geocode_addresses)

**Files:**
- Modify: `R/geocode.R`
- Modify: `tests/testthat/test-geocode.R`

- [ ] **Step 1: Write the failing test for `geocode_addresses`**

Append to `tests/testthat/test-geocode.R`:

```r
test_that("geocode_addresses returns lookup with expected columns", {
  # Use a small synthetic dataset to test the dedup and structure logic
  raw <- tibble(
    individual_id = 1:4,
    household_id = c(1, 1, 2, 3),
    address = c("544 Sandgate Road", "544 Sandgate Road", "27 Alleena Street", NA),
    suburb = c("Clayfield", "Clayfield", "Chermside", NA),
    state = c("Queensland", "Queensland", "Queensland", NA),
    postcode = c("4011", "4011", "4032", "4000")
  )
  result <- geocode_addresses(raw)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("address", "suburb", "postcode", "geo_lon", "geo_lat", "geo_success") %in% names(result)))
  # Should deduplicate — only 2 unique non-NA addresses
  expect_equal(nrow(result), 2)
  # NA addresses should be excluded from geocoding
  expect_false(any(is.na(result$address)))
})

test_that("geocode_addresses returns coordinates for known Brisbane address", {
  raw <- tibble(
    individual_id = 1,
    household_id = 1,
    address = "544 Sandgate Road",
    suburb = "Clayfield",
    state = "Queensland",
    postcode = "4011"
  )
  result <- geocode_addresses(raw)
  # ArcGIS should return coordinates near Brisbane
  expect_true(result$geo_success[1])
  expect_true(result$geo_lon[1] > 152 && result$geo_lon[1] < 154)
  expect_true(result$geo_lat[1] > -28 && result$geo_lat[1] < -27)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-geocode.R")'`
Expected: FAIL — `geocode_addresses` not found

- [ ] **Step 3: Write minimal implementation**

Append to `R/geocode.R`:

```r
geocode_addresses <- function(raw_data) {
  unique_addresses <- raw_data |>
    filter(!is.na(address)) |>
    distinct(address, suburb, postcode, .keep_all = FALSE) |>
    mutate(
      full_address = paste(address, suburb, "Queensland", postcode, sep = ", ")
    )

  geocoded <- unique_addresses |>
    tidygeocoder::geocode(
      address = full_address,
      method = "arcgis",
      lat = "geo_lat",
      long = "geo_lon"
    )

  geocoded |>
    mutate(geo_success = !is.na(geo_lon) & !is.na(geo_lat)) |>
    select(address, suburb, postcode, geo_lon, geo_lat, geo_success)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-geocode.R")'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/geocode.R tests/testthat/test-geocode.R
git commit -m "feat: add geocode_addresses with ArcGIS geocoding"
```

---

### Task 3: Assign locations with fallback — `R/geocode.R` (assign_locations)

**Files:**
- Modify: `R/geocode.R`
- Modify: `tests/testthat/test-geocode.R`

- [ ] **Step 1: Write the failing test for `assign_locations`**

Append to `tests/testthat/test-geocode.R`:

```r
test_that("assign_locations assigns geocoded coords and falls back to POA centroid", {
  source(file.path(here::here(), "R", "spatial.R"))
  poa_boundaries <- load_poa_boundaries(file.path(here::here(), "data", "abs"))

  raw <- tibble(
    individual_id = 1:3,
    household_id = c(1, 1, 2),
    address = c("544 Sandgate Road", "544 Sandgate Road", NA),
    suburb = c("Clayfield", "Clayfield", NA),
    state = c("Queensland", "Queensland", NA),
    postcode = c("4011", "4011", "4000")
  )

  lookup <- tibble(
    address = "544 Sandgate Road",
    suburb = "Clayfield",
    postcode = "4011",
    geo_lon = 153.06,
    geo_lat = -27.43,
    geo_success = TRUE
  )

  result <- assign_locations(raw, lookup, poa_boundaries)
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 3)
  expect_equal(st_crs(result)$epsg, 4326L)
  # Individuals 1 & 2 should have geocoded coords
  coords <- st_coordinates(result)
  expect_equal(coords[1, "X"], 153.06)
  # Individual 3 (no address) should have postcode centroid, not NA
  expect_false(is.na(coords[3, "X"]))
  expect_false(is.na(coords[3, "Y"]))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-geocode.R")'`
Expected: FAIL — `assign_locations` not found

- [ ] **Step 3: Write minimal implementation**

Append to `R/geocode.R`:

```r
assign_locations <- function(raw_data, geocoded_lookup, poa_boundaries) {
  # Join geocoded coords to individuals by address + suburb + postcode
  with_coords <- raw_data |>
    left_join(
      geocoded_lookup |> filter(geo_success),
      by = c("address", "suburb", "postcode")
    )

  # Compute POA centroids for fallback
  poa_code_col <- grep("POA_CODE", names(poa_boundaries), value = TRUE, ignore.case = TRUE)[1]
  poa_centroids <- poa_boundaries |>
    rename(postcode = !!sym(poa_code_col)) |>
    mutate(postcode = as.character(postcode)) |>
    st_centroid() |>
    mutate(
      poa_lon = st_coordinates(geometry)[, 1],
      poa_lat = st_coordinates(geometry)[, 2]
    ) |>
    st_drop_geometry() |>
    select(postcode, poa_lon, poa_lat)

  # Fill missing geocodes with POA centroid
  result <- with_coords |>
    left_join(poa_centroids, by = "postcode") |>
    mutate(
      final_lon = if_else(is.na(geo_lon), poa_lon, geo_lon),
      final_lat = if_else(is.na(geo_lat), poa_lat, geo_lat)
    ) |>
    select(individual_id, household_id, address, suburb, state, postcode,
           final_lon, final_lat, geo_success) |>
    mutate(geo_success = replace_na(geo_success, FALSE)) |>
    st_as_sf(coords = c("final_lon", "final_lat"), crs = 4326)

  result
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-geocode.R")'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/geocode.R tests/testthat/test-geocode.R
git commit -m "feat: add assign_locations with POA centroid fallback"
```

---

### Task 4: Family classification — `R/family.R`

**Files:**
- Create: `R/family.R`
- Create: `tests/testthat/test-family.R`

- [ ] **Step 1: Write the failing test for `classify_households`**

```r
# tests/testthat/test-family.R
# ABOUTME: Tests for household classification into family/non-family
# ABOUTME: Validates 3+ people threshold and correct column additions

library(testthat)
library(tibble)
library(dplyr)
library(sf)
source(file.path(here::here(), "R", "family.R"))

test_that("classify_households adds household_size and is_family columns", {
  # 3 in household 1 (family), 2 in household 2 (not family), 1 in household 3 (not family)
  individuals <- tibble(
    individual_id = 1:6,
    household_id = c(1, 1, 1, 2, 2, 3),
    postcode = rep("4000", 6),
    lon = 153.0,
    lat = -27.5
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)

  result <- classify_households(individuals)
  expect_true("household_size" %in% names(result))
  expect_true("is_family" %in% names(result))

  # Household 1 has 3 people → family
  h1 <- result |> filter(household_id == 1)
  expect_equal(unique(h1$household_size), 3)
  expect_true(all(h1$is_family))

  # Household 2 has 2 people → not family
  h2 <- result |> filter(household_id == 2)
  expect_equal(unique(h2$household_size), 2)
  expect_false(any(h2$is_family))

  # Household 3 has 1 person → not family
  h3 <- result |> filter(household_id == 3)
  expect_equal(unique(h3$household_size), 1)
  expect_false(any(h3$is_family))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-family.R")'`
Expected: FAIL — `classify_households` not found

- [ ] **Step 3: Write minimal implementation**

```r
# R/family.R
# ABOUTME: Classifies households by size and identifies family households (3+ people)
# ABOUTME: Adds household_size and is_family columns to individual-level data

library(dplyr)

classify_households <- function(geo_individuals) {
  household_sizes <- geo_individuals |>
    sf::st_drop_geometry() |>
    count(household_id, name = "household_size")

  geo_individuals |>
    left_join(household_sizes, by = "household_id") |>
    mutate(is_family = household_size >= 3)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-family.R")'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/family.R tests/testthat/test-family.R
git commit -m "feat: add classify_households for family identification"
```

---

## Chunk 2: Routing and Aggregation

### Task 5: Route individuals to locations — `R/route_geocoded.R`

**Files:**
- Create: `R/route_geocoded.R`
- Create: `tests/testthat/test-route_geocoded.R`

**Context:** This reuses `build_osrm_table_url`, `parse_osrm_table_response`, and `chunk_indices` from `R/osrm.R`. The key adapter step: `parse_osrm_table_response` returns `mb_code` as the row ID; we pass `individual_id` values as the `mb_codes` argument, then rename `mb_code` → `individual_id` in the result.

- [ ] **Step 1: Write the failing test (unit test with simulated OSRM)**

```r
# tests/testthat/test-route_geocoded.R
# ABOUTME: Tests for routing geocoded individuals to target locations via OSRM
# ABOUTME: Unit tests use parse_osrm_table_response directly; integration tests need OSRM server

library(testthat)
library(tibble)
library(dplyr)
library(sf)
source(file.path(here::here(), "R", "osrm.R"))
source(file.path(here::here(), "R", "route_geocoded.R"))

test_that("route_individuals_to_locations returns correct schema with simulated response", {
  # This tests the adapter logic around parse_osrm_table_response
  # Simulate what parse_osrm_table_response returns when called with individual IDs
  response <- list(
    code = "Ok",
    durations = matrix(c(900, 1200, 1500, 1800, 2100, 2400), nrow = 2, ncol = 3),
    distances = matrix(c(10000, 15000, 20000, 25000, 30000, 35000), nrow = 2, ncol = 3)
  )
  individual_ids <- c("101", "102")
  loc_ids <- c("loc_1", "loc_2", "loc_3")

  # Call parse directly to verify the adapter pattern
  raw_result <- parse_osrm_table_response(response, individual_ids, loc_ids)
  expect_true("mb_code" %in% names(raw_result))

  # Adapter: rename mb_code to individual_id
  adapted <- raw_result |> rename(individual_id = mb_code)
  expect_true("individual_id" %in% names(adapted))
  expect_equal(nrow(adapted), 6)  # 2 individuals x 3 locations
  expect_true(all(c("individual_id", "location_id", "duration_sec", "distance_m") %in% names(adapted)))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-route_geocoded.R")'`
Expected: FAIL — source file not found

- [ ] **Step 3: Write minimal implementation**

```r
# R/route_geocoded.R
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-route_geocoded.R")'`
Expected: PASS

- [ ] **Step 5: Write integration test (requires OSRM server)**

Append to `tests/testthat/test-route_geocoded.R`:

```r
test_that("route_individuals_to_locations returns real routes (osrm_live)", {
  skip_if_not(tryCatch({
    httr2::request("http://totoro.magpie-inconnu.ts.net:5001/health") |>
      httr2::req_timeout(5) |> httr2::req_perform()
    TRUE
  }, error = function(e) FALSE), "OSRM server not available")

  source(file.path(here::here(), "R", "locations.R"))
  locations <- get_target_locations()

  individuals <- tibble(
    individual_id = c(1, 2),
    household_id = c(1, 2),
    postcode = c("4011", "4000"),
    lon = c(153.06, 153.02),
    lat = c(-27.43, -27.47)
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)

  result <- route_individuals_to_locations(individuals, locations)
  expect_equal(nrow(result), 6)  # 2 individuals x 3 locations
  expect_true(all(c("individual_id", "household_id", "postcode", "location_id",
                     "duration_min", "distance_km") %in% names(result)))
  expect_true(all(result$duration_min > 0))
  expect_true(all(result$distance_km > 0))
})
```

- [ ] **Step 6: Run integration test**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-route_geocoded.R")'`
Expected: PASS (or skip if OSRM server not running)

- [ ] **Step 7: Commit**

```bash
git add R/route_geocoded.R tests/testthat/test-route_geocoded.R
git commit -m "feat: add route_individuals_to_locations via OSRM"
```

---

### Task 6: Aggregation functions — `R/aggregate_geocoded.R`

**Files:**
- Create: `R/aggregate_geocoded.R`
- Create: `tests/testthat/test-aggregate_geocoded.R`

- [ ] **Step 1: Write the failing test for `aggregate_geo_location`**

```r
# tests/testthat/test-aggregate_geocoded.R
# ABOUTME: Tests for geocoded route aggregation to location-level stats
# ABOUTME: Validates simple means (no weighting), percentiles, and time-band percentages

library(testthat)
library(tibble)
library(dplyr)
source(file.path(here::here(), "R", "aggregate_geocoded.R"))

test_that("aggregate_geo_location computes correct stats per location", {
  routes <- tibble(
    individual_id = c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5),
    household_id = c(1, 1, 2, 2, 3, 1, 1, 2, 2, 3),
    postcode = rep("4000", 10),
    location_id = c(rep("loc_1", 5), rep("loc_2", 5)),
    duration_min = c(10, 20, 30, 40, 50, 15, 25, 35, 45, 55),
    distance_km = c(5, 10, 15, 20, 25, 7.5, 12.5, 17.5, 22.5, 27.5),
    duration_sec = c(10, 20, 30, 40, 50, 15, 25, 35, 45, 55) * 60,
    distance_m = c(5, 10, 15, 20, 25, 7.5, 12.5, 17.5, 22.5, 27.5) * 1000
  )

  result <- aggregate_geo_location(routes)
  expect_equal(nrow(result), 2)

  loc1 <- result |> filter(location_id == "loc_1")
  expect_equal(loc1$n_individuals, 5)
  expect_equal(loc1$n_households, 3)
  expect_equal(loc1$mean_duration_min, mean(c(10, 20, 30, 40, 50)))
  expect_equal(loc1$mean_distance_km, mean(c(5, 10, 15, 20, 25)))
  # All 5 are <= 60 min
  expect_equal(loc1$pct_within_60min, 100)
  # 2 of 5 are <= 15 min
  expect_equal(loc1$pct_within_15min, 40)
})

test_that("build_geo_full_matrix returns all columns", {
  routes <- tibble(
    individual_id = c(1, 2, 1, 2),
    household_id = c(1, 2, 1, 2),
    postcode = c("4000", "4001", "4000", "4001"),
    location_id = c("loc_1", "loc_1", "loc_2", "loc_2"),
    duration_min = c(10, 20, 30, 40),
    distance_km = c(5, 10, 15, 20),
    duration_sec = c(600, 1200, 1800, 2400),
    distance_m = c(5000, 10000, 15000, 20000)
  )

  result <- build_geo_full_matrix(routes)
  expect_equal(nrow(result), 4)
  expect_true(all(c("individual_id", "household_id", "postcode", "location_id",
                     "duration_min", "distance_km") %in% names(result)))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-aggregate_geocoded.R")'`
Expected: FAIL — source file not found

- [ ] **Step 3: Write minimal implementation**

```r
# R/aggregate_geocoded.R
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-aggregate_geocoded.R")'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/aggregate_geocoded.R tests/testthat/test-aggregate_geocoded.R
git commit -m "feat: add geocoded route aggregation functions"
```

---

## Chunk 3: SA Boundary Loading and Progressive Zoom

### Task 7: Load SA boundaries — `R/spatial.R` (load_sa_boundaries)

**Files:**
- Modify: `R/spatial.R`
- Create: `tests/testthat/test-spatial_sa.R`

**Context:** Follow the same `download_if_missing` + `extract_zip` + `st_read` pattern as existing `load_mb_boundaries` and `load_poa_boundaries` in `R/spatial.R`. ABS ASGS 2021 shapefiles for SA levels are at:
- SA1: `SA1_2021_AUST_SHP_GDA2020.zip`
- SA2: `SA2_2021_AUST_SHP_GDA2020.zip`
- SA3: `SA3_2021_AUST_SHP_GDA2020.zip`

All from `https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files/`

- [ ] **Step 1: Write the failing test for `load_sa_boundaries`**

```r
# tests/testthat/test-spatial_sa.R
# ABOUTME: Tests for SA-level boundary loading from ABS shapefiles
# ABOUTME: Validates that load_sa_boundaries returns sf objects for SA1, SA2, SA3

library(testthat)
library(sf)
source(file.path(here::here(), "R", "spatial.R"))

test_that("load_sa_boundaries returns sf for SA3 filtered to QLD", {
  result <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA3")
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  # Should have an SA3 code column
  sa3_col <- grep("SA3_CODE", names(result), value = TRUE, ignore.case = TRUE)
  expect_length(sa3_col, 1)
  # Should have centroid columns
  expect_true(all(c("centroid_lon", "centroid_lat") %in% names(result)))
})

test_that("load_sa_boundaries returns sf for SA2 filtered to QLD", {
  result <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA2")
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  sa2_col <- grep("SA2_CODE", names(result), value = TRUE, ignore.case = TRUE)
  expect_length(sa2_col, 1)
})

test_that("load_sa_boundaries returns sf for SA1 filtered to QLD", {
  result <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA1")
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  sa1_col <- grep("SA1_CODE", names(result), value = TRUE, ignore.case = TRUE)
  expect_length(sa1_col, 1)
})

test_that("load_sa_boundaries rejects invalid level", {
  expect_error(load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA4"))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-spatial_sa.R")'`
Expected: FAIL — `load_sa_boundaries` not found

- [ ] **Step 3: Write minimal implementation**

Append to `R/spatial.R`:

```r
# Load SA-level (SA1, SA2, SA3) boundaries for QLD
# Returns sf object with centroid coordinates appended
load_sa_boundaries <- function(abs_dir = "data/abs", level = "SA3") {
  level <- toupper(level)
  if (!level %in% c("SA1", "SA2", "SA3")) {
    stop("level must be one of: SA1, SA2, SA3")
  }

  pattern <- paste0(level, "_2021.*\\.shp$")
  shp_files <- list.files(abs_dir, pattern = pattern, full.names = TRUE, recursive = TRUE)

  if (length(shp_files) == 0) {
    zip_name <- paste0(level, "_2021_AUST_SHP_GDA2020.zip")
    zip_url <- paste0(
      "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/",
      "jul2021-jun2026/access-and-downloads/digital-boundary-files/", zip_name
    )
    zip_path <- file.path(abs_dir, zip_name)
    tryCatch(
      download_if_missing(zip_url, zip_path),
      error = function(e) {
        stop(
          "Could not download ", level, " boundaries. Please download manually from:\n",
          "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files\n",
          "Save the ", level, " shapefile zip to: ", zip_path
        )
      }
    )
    extract_zip(zip_path, file.path(abs_dir, paste0(tolower(level), "_shp")))
    shp_files <- list.files(abs_dir, pattern = pattern, full.names = TRUE, recursive = TRUE)
  }

  if (length(shp_files) == 0) stop("No ", level, " shapefile found in ", abs_dir)

  sa <- st_read(shp_files[1], quiet = TRUE)

  # Filter to QLD (state code 3)
  ste_col <- grep("STE_CODE|STATE_CODE", names(sa), value = TRUE, ignore.case = TRUE)[1]
  if (!is.na(ste_col)) {
    sa <- sa |> filter(!!sym(ste_col) %in% c("3"))
  }

  # Compute and append centroids
  centroids <- st_centroid(sa)
  sa$centroid_lon <- st_coordinates(centroids)[, 1]
  sa$centroid_lat <- st_coordinates(centroids)[, 2]

  sa
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-spatial_sa.R")'`
Expected: PASS (will download shapefiles on first run)

- [ ] **Step 5: Commit**

```bash
git add R/spatial.R tests/testthat/test-spatial_sa.R
git commit -m "feat: add load_sa_boundaries for SA1/SA2/SA3 shapefiles"
```

---

### Task 8: Progressive zoom functions — `R/zoom_candidates.R`

**Files:**
- Create: `R/zoom_candidates.R`
- Create: `tests/testthat/test-zoom_candidates.R`

- [ ] **Step 1: Write the failing test for `zoom_filter`**

```r
# tests/testthat/test-zoom_candidates.R
# ABOUTME: Tests for progressive zoom candidate location functions
# ABOUTME: Validates zoom_filter percentage selection and route_population_to_centroids schema

library(testthat)
library(tibble)
library(dplyr)
source(file.path(here::here(), "R", "zoom_candidates.R"))

test_that("zoom_filter keeps top N percent by lowest mean travel time", {
  candidates <- tibble(
    area_code = paste0("SA_", 1:10),
    mean_duration_min = c(10, 20, 30, 40, 50, 60, 70, 80, 90, 100)
  )

  # Keep top 30% = 3 areas
  result <- zoom_filter(candidates, top_pct = 0.30)
  expect_equal(length(result), 3)
  expect_equal(result, c("SA_1", "SA_2", "SA_3"))
})

test_that("zoom_filter keeps at least 1 area", {
  candidates <- tibble(
    area_code = c("SA_1"),
    mean_duration_min = c(10)
  )
  result <- zoom_filter(candidates, top_pct = 0.10)
  expect_equal(length(result), 1)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-zoom_candidates.R")'`
Expected: FAIL — source file not found

- [ ] **Step 3: Write `zoom_filter` implementation**

```r
# R/zoom_candidates.R
# ABOUTME: Progressive zoom optimal location finder via SA3 → SA2 → SA1 → MB funnel
# ABOUTME: Routes geocoded individuals to candidate centroids, keeping top N% at each level

library(dplyr)
library(purrr)
library(sf)
library(httr2)
library(tibble)

zoom_filter <- function(candidate_results, top_pct = 0.10) {
  n_keep <- max(1, ceiling(nrow(candidate_results) * top_pct))
  candidate_results |>
    arrange(mean_duration_min) |>
    head(n_keep) |>
    pull(area_code)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-zoom_candidates.R")'`
Expected: PASS

- [ ] **Step 5: Write `route_population_to_centroids` implementation**

Append to `R/zoom_candidates.R`:

```r
route_population_to_centroids <- function(individuals_sf, candidate_centroids,
                                          area_code_col = "area_code",
                                          osrm_url = "http://totoro.magpie-inconnu.ts.net:5001") {
  ind_coords <- individuals_sf |>
    mutate(
      ind_lon = st_coordinates(geometry)[, 1],
      ind_lat = st_coordinates(geometry)[, 2],
      ind_id = as.character(row_number())
    ) |>
    st_drop_geometry()

  cand_data <- candidate_centroids |>
    st_drop_geometry() |>
    select(area_code = !!sym(area_code_col), lon = centroid_lon, lat = centroid_lat)

  # Batch candidates (destinations) in groups of 20, sources in groups of 75
  dest_batch_size <- 20
  src_chunk_size <- 75

  dest_batches <- chunk_indices(nrow(cand_data), dest_batch_size)

  message("Routing ", nrow(ind_coords), " individuals to ", nrow(cand_data), " candidate centroids")

  all_results <- map(seq_along(dest_batches), function(di) {
    dest_batch <- cand_data |> slice(dest_batches[[di]])
    dest_tibble <- dest_batch |> select(lon, lat)
    dest_ids <- dest_batch$area_code

    src_chunks <- chunk_indices(nrow(ind_coords), src_chunk_size)

    map(src_chunks, function(src_idx) {
      chunk <- ind_coords |> slice(src_idx)

      chunk |>
        select(lon = ind_lon, lat = ind_lat) |>
        build_osrm_table_url(dest_tibble, base_url = osrm_url) |>
        request() |>
        req_timeout(120) |>
        req_retry(max_tries = 3, backoff = ~ 2) |>
        req_perform() |>
        resp_body_json() |>
        (\(resp) {
          if (resp$code != "Ok") { warning("OSRM error: ", resp$code); return(NULL) }
          parse_osrm_table_response(resp, chunk$ind_id, dest_ids)
        })()
    }, .progress = TRUE) |>
      bind_rows()
  }) |>
    bind_rows() |>
    mutate(
      duration_min = duration_sec / 60,
      distance_km = distance_m / 1000
    )

  # Summarise: mean travel time per candidate
  # mb_code holds individual IDs (sources), location_id holds area codes (destinations)
  all_results |>
    group_by(area_code = location_id) |>
    summarise(
      mean_duration_min = mean(duration_min, na.rm = TRUE),
      mean_distance_km = mean(distance_km, na.rm = TRUE),
      .groups = "drop"
    )
}
```

- [ ] **Step 6: Write `run_progressive_zoom` implementation**

Append to `R/zoom_candidates.R`:

```r
run_progressive_zoom <- function(individuals_sf, sa3_boundaries, sa2_boundaries,
                                  sa1_boundaries, mb_boundaries,
                                  osrm_url = "http://totoro.magpie-inconnu.ts.net:5001") {
  # Identify SA3 code column
  sa3_code_col <- grep("SA3_CODE", names(sa3_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa2_code_col <- grep("SA2_CODE", names(sa2_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa1_code_col <- grep("SA1_CODE", names(sa1_boundaries), value = TRUE, ignore.case = TRUE)[1]
  mb_code_col <- grep("MB_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  # SA2-in-SA3 and SA1-in-SA2 mapping columns
  sa2_in_sa3_col <- grep("SA3_CODE", names(sa2_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa1_in_sa2_col <- grep("SA2_CODE", names(sa1_boundaries), value = TRUE, ignore.case = TRUE)[1]
  mb_in_sa1_col <- grep("SA1_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  # --- Level 1: SA3 (keep 30%) ---
  message("=== Zoom Level 1: SA3 ===")
  sa3_candidates <- sa3_boundaries |>
    rename(area_code = !!sym(sa3_code_col))
  sa3_results <- route_population_to_centroids(individuals_sf, sa3_candidates, "area_code", osrm_url)
  sa3_survivors <- zoom_filter(sa3_results, 0.30)
  message("SA3: ", length(sa3_survivors), " of ", nrow(sa3_results), " survive")

  # --- Level 2: SA2 within surviving SA3s (keep 20%) ---
  message("=== Zoom Level 2: SA2 ===")
  sa2_candidates <- sa2_boundaries |>
    filter(!!sym(sa2_in_sa3_col) %in% sa3_survivors) |>
    rename(area_code = !!sym(sa2_code_col))
  sa2_results <- route_population_to_centroids(individuals_sf, sa2_candidates, "area_code", osrm_url)
  sa2_survivors <- zoom_filter(sa2_results, 0.20)
  message("SA2: ", length(sa2_survivors), " of ", nrow(sa2_results), " survive")

  # --- Level 3: SA1 within surviving SA2s (keep 10%) ---
  message("=== Zoom Level 3: SA1 ===")
  sa1_candidates <- sa1_boundaries |>
    filter(!!sym(sa1_in_sa2_col) %in% sa2_survivors) |>
    rename(area_code = !!sym(sa1_code_col))
  sa1_results <- route_population_to_centroids(individuals_sf, sa1_candidates, "area_code", osrm_url)
  sa1_survivors <- zoom_filter(sa1_results, 0.10)
  message("SA1: ", length(sa1_survivors), " of ", nrow(sa1_results), " survive")

  # --- Level 4: MB within surviving SA1s (keep 10%) ---
  message("=== Zoom Level 4: Mesh Blocks ===")
  mb_candidates <- mb_boundaries |>
    filter(!!sym(mb_in_sa1_col) %in% sa1_survivors) |>
    rename(area_code = !!sym(mb_code_col))

  # Compute centroids for MBs if not already present
  if (!"centroid_lon" %in% names(mb_candidates)) {
    mb_centroids <- st_centroid(mb_candidates)
    mb_candidates$centroid_lon <- st_coordinates(mb_centroids)[, 1]
    mb_candidates$centroid_lat <- st_coordinates(mb_centroids)[, 2]
  }

  mb_results <- route_population_to_centroids(individuals_sf, mb_candidates, "area_code", osrm_url)
  mb_survivors <- zoom_filter(mb_results, 0.10)
  message("MB: ", length(mb_survivors), " of ", nrow(mb_results), " survive")

  # Build final ranking
  ranking <- mb_results |>
    arrange(mean_duration_min) |>
    mutate(rank = row_number())

  list(
    sa3 = sa3_results,
    sa2 = sa2_results,
    sa1 = sa1_results,
    mb = mb_results,
    ranking = ranking
  )
}
```

- [ ] **Step 7: Write integration test for `run_progressive_zoom`**

Append to `tests/testthat/test-zoom_candidates.R`:

```r
test_that("run_progressive_zoom returns expected list structure (osrm_live)", {
  skip_if_not(tryCatch({
    httr2::request("http://totoro.magpie-inconnu.ts.net:5001/health") |>
      httr2::req_timeout(5) |> httr2::req_perform()
    TRUE
  }, error = function(e) FALSE), "OSRM server not available")

  source(file.path(here::here(), "R", "osrm.R"))
  source(file.path(here::here(), "R", "spatial.R"))

  sa3 <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA3")
  sa2 <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA2")
  sa1 <- load_sa_boundaries(file.path(here::here(), "data", "abs"), "SA1")
  mb <- load_mb_boundaries(file.path(here::here(), "data", "abs"))

  # Use 3 test individuals
  individuals <- tibble::tibble(
    individual_id = 1:3,
    household_id = c(1, 1, 2),
    postcode = c("4000", "4000", "4011"),
    lon = c(153.02, 153.03, 153.06),
    lat = c(-27.47, -27.46, -27.43)
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)

  result <- run_progressive_zoom(individuals, sa3, sa2, sa1, mb)
  expect_type(result, "list")
  expect_true(all(c("sa3", "sa2", "sa1", "mb", "ranking") %in% names(result)))
  expect_s3_class(result$ranking, "tbl_df")
  expect_true("rank" %in% names(result$ranking))
  expect_true("mean_duration_min" %in% names(result$ranking))
})
```

- [ ] **Step 8: Run all zoom tests**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-zoom_candidates.R")'`
Expected: PASS (unit tests always, integration test if OSRM running)

- [ ] **Step 9: Commit**

```bash
git add R/zoom_candidates.R tests/testthat/test-zoom_candidates.R
git commit -m "feat: add progressive zoom optimal location finder"
```

---

## Chunk 4: Visualizations

### Task 9: Violin plots and point maps — `R/visualize_geocoded.R`

**Files:**
- Create: `R/visualize_geocoded.R`
- Create: `tests/testthat/test-visualize_geocoded.R`

- [ ] **Step 1: Write the failing test for `make_geo_violin`**

```r
# tests/testthat/test-visualize_geocoded.R
# ABOUTME: Tests for geocoded visualization functions
# ABOUTME: Validates that violin plots, point maps, summary tables, and zoom maps produce output files

library(testthat)
library(tibble)
library(dplyr)
library(sf)
source(file.path(here::here(), "R", "visualize_geocoded.R"))
source(file.path(here::here(), "R", "locations.R"))

test_that("make_geo_violin creates a PNG file", {
  locations <- get_target_locations()

  routes <- tibble(
    individual_id = rep(1:10, 3),
    household_id = rep(c(1,1,2,2,3,3,4,4,5,5), 3),
    postcode = rep("4000", 30),
    location_id = rep(c("loc_1", "loc_2", "loc_3"), each = 10),
    duration_min = runif(30, 5, 60),
    distance_km = runif(30, 2, 40),
    duration_sec = duration_min * 60,
    distance_m = distance_km * 1000
  )

  withr::with_tempdir({
    dir.create("output", showWarnings = FALSE)
    result <- make_geo_violin(routes, locations, "output/test_violin.png")
    expect_true(file.exists(result))
    expect_true(file.size(result) > 0)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-visualize_geocoded.R")'`
Expected: FAIL — source file not found

- [ ] **Step 3: Write `make_geo_violin` implementation**

```r
# R/visualize_geocoded.R
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-visualize_geocoded.R")'`
Expected: PASS

- [ ] **Step 5: Write `make_geo_point_map`**

Append to `R/visualize_geocoded.R`:

```r
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
      color = ~pal(ind_data$best_duration),
      fillColor = ~pal(ind_data$best_duration),
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
```

- [ ] **Step 6: Write test for `make_geo_point_map`**

Append to `tests/testthat/test-visualize_geocoded.R`:

```r
test_that("make_geo_point_map creates an HTML file", {
  locations <- get_target_locations()

  individuals <- tibble(
    individual_id = 1:5,
    household_id = c(1, 1, 2, 2, 3),
    postcode = rep("4000", 5),
    lon = c(153.02, 153.03, 153.04, 153.05, 153.06),
    lat = c(-27.47, -27.46, -27.45, -27.44, -27.43)
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)

  routes <- tibble(
    individual_id = rep(1:5, 3),
    household_id = rep(c(1,1,2,2,3), 3),
    postcode = rep("4000", 15),
    location_id = rep(c("loc_1","loc_2","loc_3"), each = 5),
    duration_min = runif(15, 5, 60),
    distance_km = runif(15, 2, 40)
  )

  withr::with_tempdir({
    dir.create("output", showWarnings = FALSE)
    result <- make_geo_point_map(individuals, routes, locations, "output/test_map.html")
    expect_true(file.exists(result))
  })
})
```

- [ ] **Step 7: Run tests**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-visualize_geocoded.R")'`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add R/visualize_geocoded.R tests/testthat/test-visualize_geocoded.R
git commit -m "feat: add geo violin plots and point maps"
```

---

### Task 10: Summary table and zoom map — `R/visualize_geocoded.R`

**Files:**
- Modify: `R/visualize_geocoded.R`
- Modify: `tests/testthat/test-visualize_geocoded.R`

- [ ] **Step 1: Write `make_geo_summary_table`**

Append to `R/visualize_geocoded.R`:

```r
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
```

- [ ] **Step 2: Write `make_zoom_map`**

Append to `R/visualize_geocoded.R`:

```r
make_zoom_map <- function(zoom_result, locations, output_path) {
  # The zoom_result is a list with sa3, sa2, sa1, mb tibbles
  # Each has area_code and mean_duration_min

  loc_data <- locations |>
    mutate(
      coords = st_coordinates(geometry) |> as_tibble(),
      lon = coords$X,
      lat = coords$Y,
      popup = paste0("<strong>", name, "</strong><br/>", address, "<br/>Role: ", role)
    ) |>
    st_drop_geometry()
  loc_cols <- location_colors(locations)

  # Load boundaries to join geometry back to results
  sa3_boundaries <- load_sa_boundaries("data/abs", "SA3")
  sa2_boundaries <- load_sa_boundaries("data/abs", "SA2")
  sa1_boundaries <- load_sa_boundaries("data/abs", "SA1")
  mb_boundaries <- load_mb_boundaries("data/abs")

  sa3_code_col <- grep("SA3_CODE", names(sa3_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa2_code_col <- grep("SA2_CODE", names(sa2_boundaries), value = TRUE, ignore.case = TRUE)[1]
  sa1_code_col <- grep("SA1_CODE", names(sa1_boundaries), value = TRUE, ignore.case = TRUE)[1]
  mb_code_col <- grep("MB_CODE", names(mb_boundaries), value = TRUE, ignore.case = TRUE)[1]

  join_results <- function(boundaries, code_col, results) {
    boundaries |>
      rename(area_code = !!sym(code_col)) |>
      inner_join(results, by = "area_code")
  }

  sa3_sf <- join_results(sa3_boundaries, sa3_code_col, zoom_result$sa3)
  sa2_sf <- join_results(sa2_boundaries, sa2_code_col, zoom_result$sa2)
  sa1_sf <- join_results(sa1_boundaries, sa1_code_col, zoom_result$sa1)
  mb_sf <- join_results(mb_boundaries, mb_code_col, zoom_result$mb)

  # Common palette across all levels
  all_durations <- c(sa3_sf$mean_duration_min, sa2_sf$mean_duration_min,
                     sa1_sf$mean_duration_min, mb_sf$mean_duration_min)
  pal <- colorNumeric(palette = "YlOrRd", domain = range(all_durations, na.rm = TRUE))

  make_popup <- function(code, dur) {
    paste0("Area: ", code, "<br/>Mean travel: ", round(dur, 1), " min")
  }

  m <- leaflet() |>
    addTiles() |>
    addPolygons(data = sa3_sf, fillColor = ~pal(mean_duration_min), fillOpacity = 0.5,
                weight = 1, color = "#333", group = "SA3",
                popup = ~make_popup(area_code, mean_duration_min)) |>
    addPolygons(data = sa2_sf, fillColor = ~pal(mean_duration_min), fillOpacity = 0.5,
                weight = 1, color = "#555", group = "SA2",
                popup = ~make_popup(area_code, mean_duration_min)) |>
    addPolygons(data = sa1_sf, fillColor = ~pal(mean_duration_min), fillOpacity = 0.6,
                weight = 1, color = "#777", group = "SA1",
                popup = ~make_popup(area_code, mean_duration_min)) |>
    addPolygons(data = mb_sf, fillColor = ~pal(mean_duration_min), fillOpacity = 0.7,
                weight = 1, color = "#999", group = "Mesh Blocks",
                popup = ~make_popup(area_code, mean_duration_min)) |>
    addCircleMarkers(
      lng = loc_data$lon, lat = loc_data$lat,
      radius = 10, color = loc_cols, fillColor = loc_cols, fillOpacity = 1,
      popup = loc_data$popup, group = "Existing Locations"
    ) |>
    addLayersControl(
      overlayGroups = c("SA3", "SA2", "SA1", "Mesh Blocks", "Existing Locations"),
      options = layersControlOptions(collapsed = FALSE)
    ) |>
    hideGroup(c("SA3", "SA2", "SA1")) |>
    addLegend(position = "bottomright", pal = pal, values = all_durations,
              title = "Mean Travel Time (min)")

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  saveWidget(m, file = normalizePath(output_path, mustWork = FALSE), selfcontained = TRUE)
  output_path
}
```

- [ ] **Step 3: Write tests for summary table**

Append to `tests/testthat/test-visualize_geocoded.R`:

```r
test_that("make_geo_summary_table creates an HTML file", {
  locations <- get_target_locations()

  stats <- tibble(
    location_id = c("loc_1", "loc_2", "loc_3"),
    n_individuals = c(100, 100, 100),
    n_households = c(30, 30, 30),
    mean_distance_km = c(10, 20, 15),
    mean_duration_min = c(15, 25, 20),
    median_duration_min = c(14, 24, 19),
    p25_duration_min = c(10, 18, 14),
    p75_duration_min = c(20, 32, 26),
    pct_within_15min = c(50, 20, 35),
    pct_within_30min = c(80, 50, 65),
    pct_within_45min = c(95, 75, 85),
    pct_within_60min = c(100, 90, 95)
  )

  withr::with_tempdir({
    dir.create("output", showWarnings = FALSE)
    # make_geo_summary_table writes to output/geo_summary_table.html
    result <- make_geo_summary_table(stats, stats, locations)
    expect_true(file.exists(result))
  })
})
```

- [ ] **Step 4: Run tests**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-visualize_geocoded.R")'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add R/visualize_geocoded.R tests/testthat/test-visualize_geocoded.R
git commit -m "feat: add geo summary table and zoom heatmap visualizations"
```

---

## Chunk 5: Pipeline Wiring and End-to-End Testing

### Task 11: Wire all new targets into `_targets.R`

**Files:**
- Modify: `_targets.R`

- [ ] **Step 1: Append new targets to `_targets.R`**

Add the following after the existing targets list (inside the `list(...)` call, before the closing `)`):

```r
  # === Geocoded address-level analysis ===

  # --- Geocoding ---
  tar_target(geo_raw_data, read_geocoded_data("data/Brisbane Family data March 2026.xlsx")),
  tar_target(geo_address_lookup, geocode_addresses(geo_raw_data)),
  tar_target(geo_individuals, assign_locations(geo_raw_data, geo_address_lookup, poa_boundaries)),

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

  # --- SA boundaries for zoom ---
  tar_target(geo_sa3_boundaries, load_sa_boundaries("data/abs", "SA3")),
  tar_target(geo_sa2_boundaries, load_sa_boundaries("data/abs", "SA2")),
  tar_target(geo_sa1_boundaries, load_sa_boundaries("data/abs", "SA1")),

  # --- Progressive zoom ---
  tar_target(geo_community_zoom, run_progressive_zoom(geo_community, geo_sa3_boundaries, geo_sa2_boundaries, geo_sa1_boundaries, mb_boundaries)),
  tar_target(geo_families_zoom, run_progressive_zoom(geo_families, geo_sa3_boundaries, geo_sa2_boundaries, geo_sa1_boundaries, mb_boundaries)),

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
```

- [ ] **Step 2: Verify pipeline parses without error**

Run: `Rscript -e 'targets::tar_manifest() |> print(n = Inf)'`
Expected: All targets listed including `geo_*` targets, no parse errors

- [ ] **Step 3: Verify pipeline DAG renders**

Run: `Rscript -e 'targets::tar_visnetwork()'`
Expected: Opens a network graph showing old and new targets with correct dependencies

- [ ] **Step 4: Commit**

```bash
git add _targets.R
git commit -m "feat: wire geocoded analysis targets into pipeline"
```

---

### Task 12: Run the full pipeline

- [ ] **Step 1: Run `tar_make()` for geocoding targets first**

Run: `Rscript -e 'targets::tar_make(names = c("geo_raw_data", "geo_address_lookup", "geo_individuals", "geo_classified", "geo_community", "geo_families"))'`
Expected: Geocoding completes, ~170 addresses geocoded via ArcGIS

- [ ] **Step 2: Check geocoding success rate**

Run: `Rscript -e 'targets::tar_read(geo_address_lookup) |> dplyr::summarise(total = dplyr::n(), success = sum(geo_success), pct = round(success/total*100, 1))'`
Expected: High success rate (>90%)

- [ ] **Step 3: Check family classification**

Run: `Rscript -e 'cat("Community:", nrow(targets::tar_read(geo_community)), "\nFamilies:", nrow(targets::tar_read(geo_families)), "\n")'`
Expected: Community = 425, Families = some subset

- [ ] **Step 4: Run routing targets**

Run: `Rscript -e 'targets::tar_make(names = c("geo_community_routes", "geo_families_routes"))'`
Expected: OSRM routing completes for both populations

- [ ] **Step 5: Run aggregation and visualization targets**

Run: `Rscript -e 'targets::tar_make(names = c("geo_community_stats", "geo_families_stats", "geo_community_violin", "geo_families_violin", "geo_community_map", "geo_families_map", "geo_summary_table", "geo_community_stats_csv", "geo_families_stats_csv", "geo_community_matrix_csv", "geo_families_matrix_csv"))'`
Expected: All CSVs and visualizations generated in `output/`

- [ ] **Step 6: Run zoom targets**

Run: `Rscript -e 'targets::tar_make(names = c("geo_sa3_boundaries", "geo_sa2_boundaries", "geo_sa1_boundaries", "geo_community_zoom", "geo_families_zoom", "geo_community_zoom_csv", "geo_families_zoom_csv", "geo_community_zoom_map", "geo_families_zoom_map"))'`
Expected: Progressive zoom completes, zoom maps and ranking CSVs generated

- [ ] **Step 7: Verify all outputs exist**

Run: `ls -la output/geo_*`
Expected: All 13 output files present with non-zero sizes

- [ ] **Step 8: Run all tests**

Run: `Rscript -e 'testthat::test_dir("tests/testthat")'`
Expected: All tests pass (old and new)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: complete geocoded travel analysis pipeline — all targets verified"
```
