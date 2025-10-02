# Test setup - helpers for testing

# NOTE: Do NOT source R/ files here!
# During devtools::check(), the package is installed and loaded.
# During devtools::load_all() + test_dir(), devtools loads the package.
# Either way, all R/ functions are available via the package namespace.

# Helper to get path to synthetic data files
# Works both during development and in installed package
get_synthetic_file <- function(filename = "synthetic_01.mat") {
  # Try package installation location first (works in devtools::check())
  pkg_path <- system.file("extdata/synthetic", filename, package = "itrackvalr")
  
  if (pkg_path != "" && file.exists(pkg_path)) {
    return(pkg_path)
  }
  
  # Fall back to development location (works with devtools::load_all())
  if (requireNamespace("here", quietly = TRUE)) {
    dev_path <- here::here("inst/extdata/synthetic", filename)
    if (file.exists(dev_path)) {
      return(dev_path)
    }
  }
  
  # Last resort: relative path from package root
  rel_path <- file.path("inst/extdata/synthetic", filename)
  if (file.exists(rel_path)) {
    return(rel_path)
  }
  
  # If nothing works, skip the test
  testthat::skip(paste("Synthetic data file not found:", filename))
}

# No other setup needed - package functions loaded automatically
