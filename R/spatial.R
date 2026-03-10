# ABOUTME: Functions to download and load ABS spatial data (MB boundaries, POA boundaries, allocation, population)
# ABOUTME: Caches downloads in data/abs/ to avoid re-downloading

library(sf)
library(dplyr)
library(readr)

# Download a file if it doesn't already exist locally
download_if_missing <- function(url, dest_path) {
  if (file.exists(dest_path)) {
    message("Using cached: ", dest_path)
    return(dest_path)
  }
  dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
  message("Downloading: ", url)
  download.file(url, dest_path, mode = "wb")
  dest_path
}

# Extract a zip file, return the directory containing extracted files
extract_zip <- function(zip_path, exdir = NULL) {
  if (is.null(exdir)) {
    exdir <- tools::file_path_sans_ext(zip_path)
  }
  if (!dir.exists(exdir)) {
    unzip(zip_path, exdir = exdir)
  }
  exdir
}

# Load Mesh Block 2021 boundaries for QLD + NSW (border postcodes)
# Returns sf object with MB_CODE_2021 and geometry
load_mb_boundaries <- function(abs_dir = "data/abs") {
  # Look for already-extracted shapefile
  shp_files <- list.files(abs_dir, pattern = "MB_2021.*\\.shp$", full.names = TRUE, recursive = TRUE)
  if (length(shp_files) == 0) {
    zip_url <- "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files/MB_2021_AUST_SHP_GDA2020.zip"
    zip_path <- file.path(abs_dir, "MB_2021_AUST_SHP_GDA2020.zip")
    tryCatch(
      download_if_missing(zip_url, zip_path),
      error = function(e) {
        stop(
          "Could not download MB boundaries. Please download manually from:\n",
          "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files\n",
          "Save the MB shapefile zip to: ", zip_path
        )
      }
    )
    extract_zip(zip_path, file.path(abs_dir, "mb_shp"))
    shp_files <- list.files(abs_dir, pattern = "MB_2021.*\\.shp$", full.names = TRUE, recursive = TRUE)
  }
  if (length(shp_files) == 0) stop("No MB shapefile found in ", abs_dir)
  mb <- st_read(shp_files[1], quiet = TRUE)
  # Filter to QLD (3) + NSW (1) to handle border postcodes
  ste_col <- grep("STE_CODE|STATE_CODE", names(mb), value = TRUE, ignore.case = TRUE)[1]
  if (is.na(ste_col)) stop("No state code column found in MB boundaries. Columns: ", paste(names(mb), collapse = ", "))
  mb <- mb |> filter(!!sym(ste_col) %in% c("1", "3"))
  mb
}

# Load POA 2021 boundaries
load_poa_boundaries <- function(abs_dir = "data/abs") {
  shp_files <- list.files(abs_dir, pattern = "POA_2021.*\\.shp$", full.names = TRUE, recursive = TRUE)
  if (length(shp_files) == 0) {
    zip_url <- "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files/POA_2021_AUST_GDA2020_SHP.zip"
    zip_path <- file.path(abs_dir, "POA_2021_AUST_GDA2020_SHP.zip")
    tryCatch(
      download_if_missing(zip_url, zip_path),
      error = function(e) {
        stop(
          "Could not download POA boundaries. Please download manually from:\n",
          "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files\n",
          "Save the POA shapefile zip to: ", zip_path
        )
      }
    )
    extract_zip(zip_path, file.path(abs_dir, "poa_shp"))
    shp_files <- list.files(abs_dir, pattern = "POA_2021.*\\.shp$", full.names = TRUE, recursive = TRUE)
  }
  if (length(shp_files) == 0) stop("No POA shapefile found in ", abs_dir)
  st_read(shp_files[1], quiet = TRUE)
}

# Load MB-to-POA allocation from ASGS POA allocation file (XLSX)
# NOTE: The main MB_2021_AUST allocation does NOT include POA.
# POA mapping is in a SEPARATE file: POA_2021_AUST.xlsx
# Returns tibble with mb_code and poa_code columns
load_mb_allocation <- function(abs_dir = "data/abs") {
  xlsx_path <- file.path(abs_dir, "POA_2021_AUST.xlsx")
  if (!file.exists(xlsx_path)) {
    xlsx_url <- "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/allocation-files/POA_2021_AUST.xlsx"
    tryCatch(
      download_if_missing(xlsx_url, xlsx_path),
      error = function(e) {
        stop(
          "Could not download POA allocation file. Please download manually from:\n",
          "https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/allocation-files\n",
          "Save POA_2021_AUST.xlsx to: ", xlsx_path
        )
      }
    )
  }
  alloc <- readxl::read_excel(xlsx_path)
  # Find MB_CODE and POA_CODE columns
  mb_col <- grep("MB_CODE", names(alloc), value = TRUE, ignore.case = TRUE)[1]
  poa_col <- grep("POA_CODE", names(alloc), value = TRUE, ignore.case = TRUE)[1]
  if (is.na(mb_col) || is.na(poa_col)) {
    stop("Could not find MB_CODE and POA_CODE columns in allocation file. Columns: ", paste(names(alloc), collapse = ", "))
  }
  alloc |>
    select(mb_code = !!sym(mb_col), poa_code = !!sym(poa_col)) |>
    mutate(across(everything(), as.character))
}

# Load Census 2021 Mesh Block population counts (dedicated XLSX, NOT from DataPacks)
# DataPacks only go down to SA1. This is the standalone MB Counts product.
# Returns tibble with mb_code and population columns
load_mb_population <- function(abs_dir = "data/abs") {
  xlsx_path <- file.path(abs_dir, "Mesh_Block_Counts_2021.xlsx")
  if (!file.exists(xlsx_path)) {
    xlsx_url <- "https://www.abs.gov.au/census/guide-census-data/mesh-block-counts/2021/Mesh%20Block%20Counts%2C%202021.xlsx"
    tryCatch(
      download_if_missing(xlsx_url, xlsx_path),
      error = function(e) {
        stop(
          "Census 2021 MB population file not found.\n",
          "Please download from: https://www.abs.gov.au/census/guide-census-data/mesh-block-counts/latest-release\n",
          "Save to: ", xlsx_path
        )
      }
    )
  }
  pop <- readxl::read_excel(xlsx_path)
  # Columns: MB_CODE_2021, Person_Usually_Resident, Dwelling
  mb_col <- grep("MB_CODE", names(pop), value = TRUE, ignore.case = TRUE)[1]
  pop_col <- grep("Person_Usually_Resident|Person.*Resident|Persons", names(pop), value = TRUE, ignore.case = TRUE)[1]
  if (is.na(mb_col) || is.na(pop_col)) {
    stop("Could not find MB_CODE and population columns. Columns: ", paste(names(pop), collapse = ", "))
  }
  pop |>
    select(mb_code = !!sym(mb_col), population = !!sym(pop_col)) |>
    mutate(mb_code = as.character(mb_code), population = as.numeric(population))
}
