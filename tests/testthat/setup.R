# Test setup - load package functions and set up test environment

# Source all R files needed for tests
source(here::here("R/read_mat_data.R"))
source(here::here("R/calibration.R"))
source(here::here("R/behavioral.R"))

# Helper to get path to synthetic data (before package is installed)
get_synthetic_file <- function(filename = "synthetic_01.mat") {
  path <- here::here("inst/extdata/synthetic", filename)
  if (!file.exists(path)) {
    testthat::skip("Synthetic data file not found")
  }
  path
}

