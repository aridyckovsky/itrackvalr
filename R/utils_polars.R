#' Polars Utility Functions
#'
#' Helper functions for working with tidypolars LazyFrames
#' These enable seamless transitions between tibble (eager) and LazyFrame (lazy)
#' processing paths for efficient large-scale data handling.

#' Check if tidypolars is available
#'
#' @description
#' Checks whether the tidypolars package is installed and can be loaded.
#' Used to conditionally enable polars processing paths.
#'
#' @return Logical indicating if tidypolars is available
#'
#' @examples
#' if (has_polars()) {
#'   # Use polars for efficient processing
#' } else {
#'   # Fall back to dplyr
#' }
#'
#' @export
has_polars <- function() {
  requireNamespace("tidypolars", quietly = TRUE) && 
    requireNamespace("polars", quietly = TRUE)
}

#' Convert tibble to polars LazyFrame
#'
#' @description
#' Converts a tibble to a polars LazyFrame for efficient lazy evaluation.
#' LazyFrames build a query plan without loading data into memory, enabling
#' processing of datasets larger than available RAM.
#'
#' @param data A tibble or data.frame to convert
#'
#' @return A polars LazyFrame
#'
#' @details
#' This function is used at the start of processing pipelines when working
#' with large datasets. Operations on the LazyFrame remain lazy until:
#' - `compute()` is called to materialize results as a tibble
#' - `sink_parquet()` is called to stream results directly to disk
#'
#' @examples
#' \dontrun{
#' samples <- read_mat_data("file.mat")$samples
#' samples_lf <- to_polars_lf(samples)
#' # Further operations remain lazy
#' }
#'
#' @export
to_polars_lf <- function(data) {
  
  if (!has_polars()) {
    cli::cli_abort(c(
      "tidypolars package is required but not installed",
      "i" = "Install with: install.packages('tidypolars', repos = 'https://community.r-multiverse.org')"
    ))
  }
  
  if (inherits(data, c("polars_lazy_frame", "LazyFrame"))) {
    # Already a LazyFrame
    return(data)
  }
  
  if (!inherits(data, c("data.frame", "tbl_df", "tbl"))) {
    cli::cli_abort("Input must be a tibble, data.frame, or polars LazyFrame")
  }
  
  # Convert to LazyFrame via tidypolars
  tryCatch(
    tidypolars::as_polars_lf(data),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to convert to LazyFrame",
        "x" = e$message
      ))
    }
  )
}

#' Convert polars LazyFrame to tibble
#'
#' @description
#' Converts a polars LazyFrame back to a tibble by computing the lazy query.
#' This materializes the data into memory.
#'
#' @param lf A polars LazyFrame
#'
#' @return A tibble
#'
#' @details
#' Use this when you need to:
#' - Materialize results for interactive inspection
#' - Pass data to functions that don't support LazyFrames
#' - Work with small enough datasets that fit in memory
#'
#' For large datasets (>1M rows), prefer `sink_parquet()` to stream directly
#' to disk instead of loading into memory.
#'
#' @examples
#' \dontrun{
#' samples_lf <- to_polars_lf(samples) |>
#'   filter(eye == "RIGHT")
#' samples_tibble <- to_tibble(samples_lf)
#' }
#'
#' @export
to_tibble <- function(lf) {
  
  if (!has_polars()) {
    cli::cli_abort(c(
      "tidypolars package is required but not installed",
      "i" = "Install with: install.packages('tidypolars', repos = 'https://community.r-multiverse.org')"
    ))
  }
  
  if (inherits(lf, c("data.frame", "tbl_df", "tbl"))) {
    # Already a tibble
    return(tibble::as_tibble(lf))
  }
  
  if (!inherits(lf, c("polars_lazy_frame", "LazyFrame"))) {
    cli::cli_abort("Input must be a polars LazyFrame or tibble")
  }
  
  # Collect the LazyFrame and convert to tibble
  # Pipeline: LazyFrame -> DataFrame -> tibble
  tryCatch(
    lf |>
      tidypolars::as_polars_df() |>
      tibble::as_tibble(),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to convert LazyFrame to tibble",
        "x" = e$message
      ))
    }
  )
}

#' Stream LazyFrame directly to Parquet file
#'
#' @description
#' Writes a polars LazyFrame directly to a Parquet file without loading
#' the full dataset into memory. This is the preferred method for exporting
#' large datasets (>1M rows).
#'
#' @param lf A polars LazyFrame
#' @param path Output file path (must end in .parquet)
#' @param compression Compression method ("snappy", "gzip", "brotli", "lz4", "zstd", "uncompressed")
#'
#' @return Invisibly returns the output path
#'
#' @details
#' Streaming export with `sink_parquet()` enables processing datasets larger
#' than available RAM. For the full CSN cohort (90M samples), this:
#' - Uses <2 GB RAM vs >10 GB for in-memory operations
#' - Writes directly to disk without materialization
#' - Applies all lazy transformations during the stream
#'
#' @examples
#' \dontrun{
#' samples_lf <- to_polars_lf(all_samples) |>
#'   filter(eye == "RIGHT") |>
#'   mutate(x_px_adj = x_px + offset_x)
#'
#' # Stream to disk without loading into memory
#' sink_parquet(samples_lf, "output/extracted/ALL_samples.parquet")
#' }
#'
#' @export
sink_parquet <- function(lf, path, compression = "snappy") {
  
  if (!has_polars()) {
    cli::cli_abort(c(
      "polars package is required but not installed",
      "i" = "Install with: install.packages('polars', repos = 'https://community.r-multiverse.org')"
    ))
  }
  
  if (!inherits(lf, c("polars_lazy_frame", "LazyFrame"))) {
    cli::cli_abort("Input must be a polars LazyFrame. Use to_polars_lf() to convert.")
  }
  
  if (!grepl("\\.parquet$", path, ignore.case = TRUE)) {
    cli::cli_abort("Output path must end with .parquet")
  }
  
  # Ensure directory exists
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  
  tryCatch({
    # Use polars native sink_parquet method
    lf$sink_parquet(
      path = path,
      compression = compression
    )
    
    # Get file size for logging
    file_size <- fs::file_size(path)
    cli::cli_alert_success("Streamed LazyFrame to {.file {basename(path)}} ({format_bytes(file_size)})")
    
    invisible(path)
  },
  error = function(e) {
    cli::cli_abort(c(
      "Failed to write Parquet file",
      "x" = e$message
    ))
  })
}

#' Format bytes to human-readable size
#'
#' @description
#' Internal helper to format byte counts as human-readable strings
#' (KB, MB, GB, etc.).
#'
#' @param bytes Numeric byte count
#'
#' @return Character string with formatted size
#'
#' @keywords internal
format_bytes <- function(bytes) {
  if (is.na(bytes) || bytes < 1024) {
    return(paste(bytes, "B"))
  }
  
  units <- c("KB", "MB", "GB", "TB")
  exp <- min(floor(log(bytes, 1024)), length(units))
  value <- bytes / (1024^exp)
  
  sprintf("%.1f %s", value, units[exp])
}

