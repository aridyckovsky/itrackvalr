#!/usr/bin/env Rscript
#' Run itrackvalr Pipeline and Export Intermediate Data
#'
#' This script runs the complete targets pipeline and exports intermediate
#' data files at each processing stage to organized directories.
#'
#' Output Structure:
#'   output/
#'     ├── raw/           # Original .mat files (future: copied here for archival)
#'     ├── extracted/     # Data extracted from .mat files
#'     ├── calibrated/    # After applying calibration offsets (PR-B)
#'     ├── preprocessed/  # Resampled, binarized data (PR-B)
#'     ├── analysis/      # Model outputs, summary statistics (PR-B/C)
#'     └── reports/       # Generated reports and figures
#'
#' Usage:
#'   Rscript run_pipeline.R
#'   
#' Or from R console:
#'   source("run_pipeline.R")

library(targets)
library(cli)

# Main function
run_itrackvalr_pipeline <- function(data_dir = "inst/extdata/synthetic",
                                     script = "_targets.R", 
                                     callr_function = NULL,
                                     clean_start = FALSE) {
  
  cli_h1("itrackvalr Pipeline Runner")
  
  # Set data directory as environment variable for targets
  Sys.setenv(ITRACKVALR_DATA_DIR = data_dir)
  cli_alert_info("Data directory: {.path {data_dir}}")
  
  # Optionally clean previous run
  if (clean_start) {
    cli_alert_info("Cleaning previous pipeline run...")
    tar_destroy(destroy = "all")
    if (dir.exists("output")) {
      unlink("output", recursive = TRUE)
      cli_alert_success("Removed old output directory")
    }
  }
  
  # Run pipeline
  cli_alert_info("Running targets pipeline from {.file {script}}")
  cli_rule()
  
  result <- tar_make(
    script = script,
    callr_function = callr_function
  )
  
  cli_rule()
  
  # Check for errors
  meta <- tar_meta(fields = c("name", "error"), complete_only = FALSE)
  errored <- meta |> dplyr::filter(!is.na(error))
  
  if (nrow(errored) > 0) {
    cli_alert_danger("Pipeline completed with {nrow(errored)} error{?s}:")
    for (i in seq_len(nrow(errored))) {
      cli_alert_danger("  {errored$name[i]}: {errored$error[i]}")
    }
  } else {
    cli_alert_success("Pipeline completed successfully!")
  }
  
  # Show outputs
  cli_h2("Exported Data Files")
  
  if (file.exists("output/MANIFEST.csv")) {
    manifest <- readr::read_csv("output/MANIFEST.csv", show_col_types = FALSE)
    
    # Summary by stage
    stage_summary <- manifest |>
      dplyr::group_by(stage) |>
      dplyr::summarise(
        n_files = dplyr::n(),
        total_size_mb = sum(size_bytes) / 1024^2,
        .groups = "drop"
      ) |>
      dplyr::arrange(stage)
    
    cli_alert_info("Files by stage:")
    for (i in seq_len(nrow(stage_summary))) {
      cli_bullets(c(
        "*" = "{.strong {stage_summary$stage[i]}}: {stage_summary$n_files[i]} file{?s} ({round(stage_summary$total_size_mb[i], 2)} MB)"
      ))
    }
    
    cli_rule()
    cli_alert_info("Full manifest: {.file output/MANIFEST.csv}")
    
    # Show file listing
    cli_h3("Exported Files")
    for (stage in unique(manifest$stage)) {
      stage_files <- manifest |> dplyr::filter(stage == .env$stage)
      if (nrow(stage_files) > 0) {
        cli_alert_info("{.strong {stage}/}")
        for (j in seq_len(nrow(stage_files))) {
          cli_bullets(c(
            " " = "{.file {stage_files$file_name[j]}} ({stage_files$size_human[j]}, {stage_files$format[j]})"
          ))
        }
      }
    }
    
  } else {
    cli_alert_warning("No manifest found")
  }
  
  cli_rule()
  
  # Pipeline visualization
  cli_h2("Pipeline Visualization")
  cli_alert_info("View pipeline graph:")
  cli_bullets(c(
    " " = "targets::tar_visnetwork()",
    " " = "targets::tar_glimpse()"
  ))
  
  cli_alert_info("Inspect specific targets:")
  cli_bullets(c(
    " " = "targets::tar_read(samples_raw)      # Gaze samples",
    " " = "targets::tar_read(events_raw)       # Event stream",
    " " = "targets::tar_read(validation_df)    # Validation metrics",
    " " = "targets::tar_read(pipeline_summary) # Summary stats"
  ))
  
  invisible(result)
}

# Run if called as script
if (!interactive()) {
  run_itrackvalr_pipeline(clean_start = FALSE)
} else {
  cli_alert_info("Loaded {.fn run_itrackvalr_pipeline}")
  cli_alert_info("Run with: {.code run_itrackvalr_pipeline()}")
  cli_alert_info("Clean start: {.code run_itrackvalr_pipeline(clean_start = TRUE)}")
}

