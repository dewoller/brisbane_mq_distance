# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

R {targets} pipeline that calculates driving distances/times from client postcodes (in `data/brisbane_family.xlsx`) to 3 candidate Brisbane locations using OSRM. Clients are distributed across ABS Census 2021 mesh blocks proportional to population, then routed via a self-hosted OSRM instance.

## Commands

```bash
# Run the full pipeline
Rscript -e 'targets::tar_make()'

# Inspect pipeline status
Rscript -e 'targets::tar_visnetwork()'

# Invalidate a target to force re-run
Rscript -e 'targets::tar_invalidate(mb_routes)'

# Run all tests
Rscript -e 'testthat::test_dir("tests/testthat")'

# Run a single test file
Rscript -e 'testthat::test_file("tests/testthat/test-osrm.R")'
```

## Architecture

**Pipeline orchestration:** `_targets.R` defines the DAG. All R functions live in `R/` and are auto-loaded by `tar_source()`.

**Data flow (in pipeline order):**

1. **read_data.R** — Reads Excel, cleans columns, aggregates individuals/households per postcode
2. **spatial.R** — Downloads/caches ABS shapefiles (MB boundaries, POA boundaries, MB-to-POA allocation, MB population counts) from abs.gov.au into `data/abs/`
3. **mb_mapping.R** — Joins mesh blocks to postcodes via allocation file, computes centroids, filters outlier postcodes (>3 SD from mean centroid distance)
4. **weights.R** — Distributes postcode-level client counts across mesh blocks proportional to MB population
5. **locations.R** — Hardcoded 3 target locations (Annerley, Riverhills, Fortitude Valley) as sf points
6. **osrm.R** — Batches MB centroids into chunks of 100, queries OSRM table API for duration+distance matrices, parses into long-format tibble
7. **aggregate.R** — Rolls up MB-level routes to postcode×location weighted stats; computes time-band percentages, percentiles
8. **visualize.R** — Produces violin plots (PNG), leaflet choropleth map (HTML), gt summary table (HTML) in `output/`

## Key Dependencies

- **OSRM server** at `http://totoro.magpie-inconnu.ts.net:5001` — required for the routing step. Tests tagged with `osrm_live` need this running.
- **ABS data files** — auto-downloaded on first run to `data/abs/`. Shapefiles are in `.gitignore`.
- R packages: targets, sf, dplyr, readxl, httr2, leaflet, ggplot2, gt, tidyr, purrr, RColorBrewer, htmlwidgets, here, withr (tests)

## Conventions

- Every R file starts with two `# ABOUTME:` comment lines describing the file's purpose.
- Tests use `source()` with relative paths or `here::here()` — not package loading.
- CRS is always EPSG:4326 (WGS84).
- Outputs go to `output/` (gitignored).
- Pipeline cache lives in `_targets/` (gitignored).
