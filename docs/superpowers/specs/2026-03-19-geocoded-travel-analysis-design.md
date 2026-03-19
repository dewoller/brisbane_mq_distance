# Geocoded Address-Level Travel Analysis Pipeline

## Overview

Extend the existing `{targets}` pipeline with a parallel analysis track that starts from geocoded street addresses instead of postcode-level mesh block estimates. Uses the new `Brisbane Family data March 2026.xlsx` dataset which includes address-level data for 425 individuals.

Two populations are analysed independently:
- **Community**: all 425 individuals
- **Families**: only households (CDS) with 3+ people

## Data Source

File: `data/Brisbane Family data March 2026.xlsx`, sheet "Raw Data"

Columns: `ID`, `CDS` (household ID), `Unit/House Number and Street/Road Name`, `Suburb`, `State`, `Postcode (Cleansed)`

- 425 rows, 368 with addresses, all 425 with postcodes
- ~170 unique address/suburb/postcode combinations
- 76 unique postcodes (same as original dataset)

## Architecture

Single `_targets.R` pipeline. New targets are prefixed `geo_` and appended after the existing targets. Existing targets are untouched.

### Approach

- **Approach C (selected):** Single pipeline, new targets clearly namespaced with `geo_` prefix. Old analysis remains as baseline. New R files for geocoding, family logic, and zoom analysis. Reuse `osrm.R` and `locations.R` directly.

## New R Files

### `R/geocode.R`

**`read_geocoded_data(path)`**
- Reads "Raw Data" sheet from the new Excel file
- Cleans column names (strips `\r\n` artifacts)
- Returns tibble: `individual_id`, `household_id`, `address`, `suburb`, `state`, `postcode`

**`geocode_addresses(raw_data)`**
- Extracts unique address/suburb/state/postcode combos (~170 unique)
- Geocodes via `tidygeocoder::geocode()` with `method = "arcgis"`
- Composite address string: `"544 Sandgate Road, Clayfield, Queensland, 4011"`
- Returns lookup table: `address`, `suburb`, `postcode`, `geo_lon`, `geo_lat`, `geo_success`

**`assign_locations(raw_data, geocoded_lookup, poa_boundaries)`**
- Joins geocoded coords back to individuals
- For failed/missing geocodes, falls back to POA centroid for that postcode
- Returns sf point data frame of all 425 individuals with final lon/lat

### `R/family.R`

**`classify_households(geo_individuals)`**
- Counts individuals per `household_id` (CDS)
- Adds `household_size` and `is_family` (TRUE if 3+ people) columns
- Returns full dataset with classification appended

**Note:** Rather than a `split_populations()` function returning a list, the pipeline uses two separate targets with simple filter expressions:
- `geo_community` target: `geo_classified` (all individuals, passed through)
- `geo_families` target: `geo_classified |> filter(is_family)` (inline filter in `_targets.R`)

This avoids the `{targets}` problem of extracting list elements as separate targets.

### `R/route_geocoded.R`

**`route_individuals_to_locations(individuals_sf, locations)`**
- Takes sf point data frame and the 3 target locations
- Extracts lon/lat, chunks into batches of 100
- Calls OSRM table API (reuses `build_osrm_table_url` from `osrm.R`)
- Calls `parse_osrm_table_response` which returns `mb_code` as the row identifier — this function renames `mb_code` to `individual_id` and joins back `household_id` and `postcode` from the input data via the individual_id
- Returns long-format tibble: `individual_id`, `household_id`, `postcode`, `location_id`, `duration_min`, `distance_km`

### `R/aggregate_geocoded.R`

**`aggregate_geo_location(routes)`**
- Groups by `location_id`
- Computes: `n_individuals`, `n_households`, `mean_distance_km`, `mean_duration_min`, `median_duration_min`, `p25_duration_min`, `p75_duration_min`, `pct_within_15min/30/45/60`
- No weighting — each row is one person

**`build_geo_full_matrix(routes)`**
- Per-individual × per-location detail table for CSV export

### `R/zoom_candidates.R`

Progressive funnel: SA3 → SA2 → SA1 → Mesh Blocks

**`route_population_to_centroids(individuals_sf, candidate_centroids)`**
- Routes any population to any set of candidate centroids via OSRM
- Returns mean travel time per candidate
- Reuses `build_osrm_table_url` / `parse_osrm_table_response`

**`zoom_filter(candidate_results, top_pct)`**
- Keeps the top N% (lowest mean travel time)
- Returns area codes for the next zoom level

**`run_progressive_zoom(individuals_sf, sa3_boundaries, sa2_boundaries, sa1_boundaries, mb_boundaries)`**
- Orchestrates the funnel with sliding percentages:

| Level | ~Areas | Keep % | ~Survivors |
|-------|--------|--------|------------|
| SA3   | ~30    | 30%    | ~9         |
| SA2   | ~63    | 20%    | ~13        |
| SA1   | ~130   | 10%    | ~13        |
| MB    | ~650   | 10%    | ~65 final  |

- Returns a named list: `list(sa3 = <tibble>, sa2 = <tibble>, sa1 = <tibble>, mb = <tibble>, ranking = <tibble of final MB rankings>)`
- The `ranking` element is directly passable to `write_csv_output` for the zoom CSV export
- The target storing this result is a list target, allowing `make_zoom_map` to access per-level data for layered rendering

### `R/visualize_geocoded.R`

**`make_geo_violin(routes, locations)`**
- Violin + boxplot, same style as existing but unweighted
- Output: `output/geo_community_violin.png`, `output/geo_families_violin.png`

**`make_geo_point_map(individuals_sf, routes, locations)`**
- Leaflet map with individual points coloured by nearest-location travel time
- 3 location markers
- Output: `output/geo_community_map.html`, `output/geo_families_map.html`

**`make_geo_summary_table(community_stats, families_stats, locations)`**
- Single combined gt table, both populations side-by-side per location
- Output: `output/geo_summary_table.html`

**`make_zoom_map(zoom_result, locations, output_path)`**
- Called once per population, returns a single file path
- Leaflet map with layer toggle for SA3/SA2/SA1/MB polygons
- Coloured by mean travel time at each level
- Final MB centroids highlighted with rankings

## Existing Files Modified

### `_targets.R`
- Append new `geo_*` targets after existing targets

### `R/spatial.R`
- Add `load_sa_boundaries(abs_dir, level)` — downloads/caches ABS shapefiles for SA1, SA2, SA3; returns sf polygons with centroids. Follows the same `download_if_missing` + `st_read` pattern as existing functions

## Existing Files NOT Modified

`osrm.R`, `locations.R`, `aggregate.R`, `visualize.R`, `read_data.R`, `mb_mapping.R`, `weights.R`, `optimal_location.R`

## Target DAG (new targets only)

```
geo_raw_data
  → geo_address_lookup
    → geo_individuals (depends on: geo_raw_data, geo_address_lookup, poa_boundaries [existing])
      → geo_classified
        → geo_community (all rows from geo_classified)
        → geo_families  (geo_classified filtered to is_family == TRUE)

locations (existing)

geo_community + locations → geo_community_routes → geo_community_stats → geo_community_stats_csv (via write_csv_output)
                                                 → geo_community_matrix_csv (via write_csv_output)
geo_families + locations  → geo_families_routes  → geo_families_stats  → geo_families_stats_csv (via write_csv_output)
                                                 → geo_families_matrix_csv (via write_csv_output)

geo_community_stats + geo_families_stats → geo_summary_table

geo_sa3_boundaries (NEW) ←── load_sa_boundaries("data/abs", "SA3")
geo_sa2_boundaries (NEW) ←── load_sa_boundaries("data/abs", "SA2")
geo_sa1_boundaries (NEW) ←── load_sa_boundaries("data/abs", "SA1")
mb_boundaries (existing)

geo_community + geo_sa3..sa1 + mb_boundaries → geo_community_zoom (list target) → geo_community_zoom_map + geo_community_zoom_csv
geo_families  + geo_sa3..sa1 + mb_boundaries → geo_families_zoom  (list target) → geo_families_zoom_map  + geo_families_zoom_csv

geo_community_routes → geo_community_violin
geo_families_routes  → geo_families_violin
geo_community + geo_community_routes → geo_community_map
geo_families  + geo_families_routes  → geo_families_map
```

## New Dependency

- `tidygeocoder` R package (for ArcGIS geocoding)

## Output Files

| File | Description |
|------|-------------|
| `output/geo_community_violin.png` | Travel time distribution, all individuals |
| `output/geo_families_violin.png` | Travel time distribution, families only |
| `output/geo_community_map.html` | Individual points map, all |
| `output/geo_families_map.html` | Individual points map, families only |
| `output/geo_summary_table.html` | Combined gt table comparing both populations |
| `output/geo_community_zoom_map.html` | Progressive zoom heatmap, all |
| `output/geo_families_zoom_map.html` | Progressive zoom heatmap, families only |
| `output/geo_community_stats.csv` | Location summary stats, all |
| `output/geo_families_stats.csv` | Location summary stats, families only |
| `output/geo_community_matrix.csv` | Full individual × location detail, all |
| `output/geo_families_matrix.csv` | Full individual × location detail, families only |
| `output/geo_community_zoom_ranking.csv` | Final MB rankings, all |
| `output/geo_families_zoom_ranking.csv` | Final MB rankings, families only |

## Key Design Decisions

1. **ArcGIS geocoder** — best free accuracy for Australian addresses, no API key needed
2. **Family = 3+ people per CDS** — counted directly from Raw Data sheet
3. **Postcode centroid fallback** — uses existing POA boundaries for failed geocodes
4. **Progressive zoom with sliding percentages** — 30%/20%/10%/10% to avoid premature elimination at coarse levels
5. **Separate output files per population** — except the summary table which combines both for comparison
6. **Reuse existing OSRM helpers** — `build_osrm_table_url` and `parse_osrm_table_response` from `osrm.R`. Note: `parse_osrm_table_response` returns `mb_code` as the row ID column; callers rename this to their own ID (e.g., `individual_id`) after the call
7. **No modification to existing pipeline** — old targets remain as baseline comparison
8. **CSV exports reuse `write_csv_output`** from existing `aggregate.R`
9. **Zoom targets are list targets** — each stores per-level results so the map can render all four layers
10. **`zoom_candidates.R` vs `optimal_location.R`** — the new file operates on geocoded individuals with a progressive spatial funnel (SA3→MB); the existing file operates on mesh-block-weighted populations and tests postcode centroids. They are independent and do not conflict
