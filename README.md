# Brisbane MQ Distance Analysis

R {targets} pipeline that calculates driving distances and travel times from client postcodes to candidate Brisbane locations using OSRM (Open Source Routing Machine).

Clients from an Excel dataset are distributed across ABS Census 2021 mesh blocks proportional to population, then routed via a self-hosted OSRM instance to produce travel statistics, maps, and rankings.

## What It Produces

- **Travel time statistics** per postcode and location (weighted mean, min, max, percentiles)
- **Violin plots** showing travel time distributions
- **Interactive leaflet maps** with choropleth travel-time layers and population overlays
- **Summary tables** (gt) for each candidate location
- **Optimal location analysis** ranking all client postcodes as potential facility sites
- **CSV exports** of all results

## Prerequisites

### 1. Install R (version 4.3 or later)

**macOS:**
```bash
# Option A: Download installer from https://cran.r-project.org/bin/macosx/
# Option B: Using Homebrew
brew install r
```

**Windows:**

Download and run the installer from https://cran.r-project.org/bin/windows/base/

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install r-base r-base-dev
```

### 2. Install system libraries (required by the sf package)

**macOS:**
```bash
brew install gdal proj geos udunits
```

**Windows:**

The sf package bundles these automatically on Windows — no extra steps needed.

**Ubuntu/Debian:**
```bash
sudo apt install libgdal-dev libproj-dev libgeos-dev libudunits2-dev
```

### 3. OSRM server access

The routing step requires an OSRM server running at `http://totoro.magpie-inconnu.ts.net:5001`. This is a private Tailnet server. If you do not have access, contact the project owner.

## Setup

### Clone the repository

```bash
git clone https://github.com/dewoller/brisbane_mq_distance.git
cd brisbane_mq_distance
```

### Install R packages

Open R (or RStudio) in the project directory and run:

```r
install.packages(c(
  "targets",
  "sf",
  "dplyr",
  "tidyr",
  "purrr",
  "readxl",
  "readr",
  "httr2",
  "ggplot2",
  "leaflet",
  "gt",
  "tibble",
  "RColorBrewer",
  "htmlwidgets",
  "here",
  "withr",
  "testthat"
))
```

This may take several minutes, especially `sf` which compiles from source on some platforms.

## Running the Pipeline

```bash
# Run from the project directory
Rscript -e 'targets::tar_make()'
```

On first run, the pipeline will automatically download ~300 MB of ABS spatial data (Census mesh block boundaries, postcode boundaries, allocation tables, and population counts) into `data/abs/`. These files are cached locally and not re-downloaded on subsequent runs.

The full pipeline takes approximately 15-30 minutes depending on OSRM server responsiveness.

### Check pipeline status

```bash
Rscript -e 'targets::tar_visnetwork()'
```

This opens an interactive dependency graph in your browser showing which targets are up to date, outdated, or errored.

### Force a target to re-run

```bash
Rscript -e 'targets::tar_invalidate(mb_routes)'
```

## Running Tests

```bash
# All tests
Rscript -e 'testthat::test_dir("tests/testthat")'

# Single test file
Rscript -e 'testthat::test_file("tests/testthat/test-osrm.R")'
```

Tests tagged `osrm_live` require the OSRM server to be reachable.

## Project Structure

```
brisbane_mq_distance/
  _targets.R          # Pipeline definition (DAG of targets)
  R/                  # All pipeline functions
    read_data.R       # Excel ingestion, postcode summarisation
    spatial.R         # ABS shapefile download/load (MB, POA boundaries, allocation, population)
    mb_mapping.R      # Join mesh blocks to postcodes, compute centroids, filter outliers
    weights.R         # Distribute client counts across mesh blocks by population
    locations.R       # Hardcoded target locations (Annerley, Riverhills, Fortitude Valley)
    osrm.R            # OSRM table API client (batch distance/duration queries)
    aggregate.R       # Roll up MB routes to postcode x location statistics
    optimal_location.R # Candidate facility location ranking
    visualize.R       # Violin plots, leaflet maps, gt tables
  data/
    brisbane_family.xlsx  # Client postcode data (included in repo)
    abs/                  # ABS spatial data (auto-downloaded, gitignored)
  tests/testthat/     # Unit tests
  output/             # Generated artifacts (gitignored)
  DESCRIPTION         # R package metadata
```

## Data Flow

1. Read client postcodes from Excel
2. Download ABS Census 2021 mesh block and postcode boundaries
3. Map mesh blocks to postcodes using ABS allocation tables
4. Distribute client counts across mesh blocks proportional to population
5. Query OSRM for driving distance/duration from each mesh block centroid to each target location
6. Aggregate results to postcode-level weighted statistics
7. Generate visualisations and CSV exports
