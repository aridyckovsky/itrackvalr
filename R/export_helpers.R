#' Export Pipeline Data Helpers
#'
#' Functions to save intermediate pipeline data to organized directories
#' in both CSV (human-readable) and Parquet (efficient) formats.

#' Create output directory structure
#' @keywords internal
create_output_dirs <- function(base_dir = "output") {
  dirs <- c(
    file.path(base_dir, "raw"),
    file.path(base_dir, "extracted"),
    file.path(base_dir, "calibrated"),
    file.path(base_dir, "preprocessed"),
    file.path(base_dir, "analysis"),
    file.path(base_dir, "reports")
  )
  
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      cli::cli_alert_success("Created {.path {dir}}")
    }
  }
  
  invisible(dirs)
}

#' Export data to CSV and Parquet
#'
#' @param data A tibble or data frame to export
#' @param stage Pipeline stage ("raw", "extracted", "calibrated", etc.)
#' @param name File name (without extension)
#' @param base_dir Base output directory (default: "output")
#' @param formats Character vector of formats: "csv", "parquet", or both
#'
#' @return Invisible list of file paths created
#' @export
export_pipeline_data <- function(data, 
                                  stage, 
                                  name, 
                                  base_dir = "output",
                                  formats = c("csv", "parquet")) {
  
  # Create stage directory
  stage_dir <- file.path(base_dir, stage)
  if (!dir.exists(stage_dir)) {
    dir.create(stage_dir, recursive = TRUE)
  }
  
  paths <- list()
  
  # Export CSV (human-readable)
  if ("csv" %in% formats) {
    csv_path <- file.path(stage_dir, paste0(name, ".csv"))
    readr::write_csv(data, csv_path)
    cli::cli_alert_success("Exported CSV: {.file {csv_path}} ({format_bytes(file.size(csv_path))})")
    paths$csv <- csv_path
  }
  
  # Export Parquet (efficient, compressed)
  if ("parquet" %in% formats) {
    # Check if arrow package is available
    if (requireNamespace("arrow", quietly = TRUE)) {
      parquet_path <- file.path(stage_dir, paste0(name, ".parquet"))
      arrow::write_parquet(data, parquet_path, compression = "snappy")
      cli::cli_alert_success("Exported Parquet: {.file {parquet_path}} ({format_bytes(file.size(parquet_path))})")
      paths$parquet <- parquet_path
    } else {
      cli::cli_alert_warning("arrow package not installed, skipping Parquet export")
    }
  }
  
  invisible(paths)
}

#' Format bytes for human-readable file sizes
#' @keywords internal
format_bytes <- function(bytes) {
  if (bytes < 1024) {
    sprintf("%d B", bytes)
  } else if (bytes < 1024^2) {
    sprintf("%.1f KB", bytes / 1024)
  } else if (bytes < 1024^3) {
    sprintf("%.1f MB", bytes / 1024^2)
  } else {
    sprintf("%.1f GB", bytes / 1024^3)
  }
}

#' Export samples data with metadata
#' @param samples Samples tibble
#' @param metadata Metadata tibble
#' @param stage Pipeline stage name
#' @param base_dir Base output directory
#' @export
export_samples <- function(samples, metadata, stage, base_dir = "output") {
  # Add metadata columns to samples for context
  samples_with_meta <- samples |>
    dplyr::mutate(
      participant_id = metadata$id,
      sampling_rate_hz = metadata$sampling_rate_hz,
      session_duration_ms = metadata$duration_ms,
      .before = 1
    )
  
  paths <- export_pipeline_data(
    data = samples_with_meta,
    stage = stage,
    name = paste0(metadata$id, "_samples"),
    base_dir = base_dir,
    formats = c("csv", "parquet")
  )
  
  # Return character vector of file paths for targets
  unlist(paths, use.names = FALSE)
}

#' Export events data with metadata
#' @param events Events tibble
#' @param metadata Metadata tibble
#' @param stage Pipeline stage name
#' @param base_dir Base output directory
#' @export
export_events <- function(events, metadata, stage, base_dir = "output") {
  # Add session metadata
  events_with_meta <- events |>
    dplyr::mutate(
      participant_id = metadata$id,
      session_duration_ms = metadata$duration_ms,
      .before = 1
    )
  
  paths <- export_pipeline_data(
    data = events_with_meta,
    stage = stage,
    name = paste0(metadata$id, "_events"),
    base_dir = base_dir,
    formats = c("csv", "parquet")
  )
  
  # Return character vector of file paths for targets
  unlist(paths, use.names = FALSE)
}

#' Export validation summaries
#' @param validation_df Validation data tibble
#' @param validation_summary Validation summary list
#' @param base_dir Base output directory
#' @export
export_validation <- function(validation_df, validation_summary, base_dir = "output") {
  
  # Export raw validation data
  export_pipeline_data(
    data = validation_df,
    stage = "extracted",
    name = "validation_metrics",
    base_dir = base_dir,
    formats = c("csv")
  )
  
  # Export subject-level summary
  export_pipeline_data(
    data = validation_summary$subject_summary,
    stage = "extracted",
    name = "validation_subject_summary",
    base_dir = base_dir,
    formats = c("csv")
  )
  
  # Export global summary
  export_pipeline_data(
    data = validation_summary$global_summary,
    stage = "extracted",
    name = "validation_global_summary",
    base_dir = base_dir,
    formats = c("csv")
  )
  
  # Export correlation and t-test results if available
  if (!is.null(validation_summary$correlation)) {
    cor_df <- broom::tidy(validation_summary$correlation)
    export_pipeline_data(
      data = cor_df,
      stage = "extracted",
      name = "validation_correlation",
      base_dir = base_dir,
      formats = c("csv")
    )
  }
  
  if (!is.null(validation_summary$paired_test)) {
    ttest_df <- broom::tidy(validation_summary$paired_test)
    export_pipeline_data(
      data = ttest_df,
      stage = "extracted",
      name = "validation_paired_test",
      base_dir = base_dir,
      formats = c("csv")
    )
  }
  
  invisible(NULL)
}

#' Create data export manifest
#'
#' @description
#' Creates a manifest file listing all exported data files with metadata
#' 
#' @param base_dir Base output directory
#' @export
create_export_manifest <- function(base_dir = "output") {
  
  # Find all CSV and Parquet files
  csv_files <- list.files(base_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  parquet_files <- list.files(base_dir, pattern = "\\.parquet$", recursive = TRUE, full.names = TRUE)
  
  all_files <- c(csv_files, parquet_files)
  
  if (length(all_files) == 0) {
    cli::cli_alert_warning("No exported files found in {.path {base_dir}}")
    return(invisible(NULL))
  }
  
  # Create manifest
  manifest <- tibble::tibble(
    file_path = all_files,
    file_name = basename(all_files),
    stage = basename(dirname(all_files)),
    format = tools::file_ext(all_files),
    size_bytes = file.size(all_files),
    size_human = vapply(file.size(all_files), format_bytes, character(1)),
    modified = file.mtime(all_files)
  ) |>
    dplyr::arrange(stage, file_name)
  
  # Export manifest
  manifest_path <- file.path(base_dir, "MANIFEST.csv")
  readr::write_csv(manifest, manifest_path)
  
  cli::cli_alert_success("Created manifest: {.file {manifest_path}}")
  cli::cli_alert_info("Total exported files: {nrow(manifest)} ({sum(manifest$size_bytes) / 1024^2 |> round(2)} MB)")
  
  manifest
}

