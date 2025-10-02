# itrackvalr targets pipeline
# PR-A: Minimal pipeline for data ingestion and validation parsing

# Load packages
library(targets)
library(tarchetypes)

# Source R functions
source("R/read_mat_data.R")
source("R/calibration.R")
source("R/behavioral.R")
source("R/export_helpers.R")

# Set target options
tar_option_set(
  packages = c(
    "R.matlab",
    "dplyr",
    "tidyr",
    "tibble",
    "stringr",
    "cli",
    "rlang",
    "here",
    "fs",
    "readr",
    "broom"
  ),
  format = "rds",
  error = "continue"
)

# Define pipeline
list(
  # Example synthetic .mat file
  tar_target(
    synthetic_file,
    "inst/extdata/synthetic/synthetic_01.mat",
    format = "file"
  ),
  
  # Read .mat data
  tar_target(
    mat_data,
    read_mat_data(synthetic_file)
  ),
  
  # Extract components
  tar_target(
    samples_raw,
    mat_data$samples
  ),
  
  tar_target(
    events_raw,
    mat_data$events
  ),
  
  tar_target(
    metadata,
    mat_data$metadata
  ),
  
  # Extract trial-level behavioral data
  tar_target(
    behavioral_trials,
    mat_data$behavioral
  ),
  
  # Classify behavioral outcomes (hits, misses, FAs, CRs)
  tar_target(
    behavioral_classified,
    classify_behavioral_outcomes(behavioral_trials)
  ),
  
  # Behavioral summary statistics
  tar_target(
    behavioral_summary,
    summarize_behavioral(behavioral_classified)
  ),
  
  # Parse validation messages
  tar_target(
    validation_df,
    parse_validation_msgs(events_raw)
  ),
  
  # Summarize validation relationships
  tar_target(
    validation_summary,
    summarize_validation_relationships(validation_df)
  ),
  
  # === DATA EXPORTS ===
  # Create output directory structure
  tar_target(
    output_dirs,
    {
      create_output_dirs("output")
    }
  ),
  
  # Export raw samples (extracted from .mat)
  tar_target(
    export_samples_raw,
    {
      output_dirs  # Dependency to ensure dirs exist
      export_samples(samples_raw, metadata, stage = "extracted")
    },
    format = "file"
  ),
  
  # Export raw events (extracted from .mat)
  tar_target(
    export_events_raw,
    {
      output_dirs  # Dependency
      export_events(events_raw, metadata, stage = "extracted")
    },
    format = "file"
  ),
  
  # Export validation summaries
  tar_target(
    export_validation_data,
    {
      output_dirs  # Dependency
      export_validation(validation_df, validation_summary, base_dir = "output")
      file.path("output/extracted", c(
        "validation_metrics.csv",
        "validation_subject_summary.csv",
        "validation_global_summary.csv"
      ))
    },
    format = "file"
  ),
  
  # Export behavioral data
  tar_target(
    export_behavioral_data,
    {
      output_dirs  # Dependency
      # Export trial-level behavioral data
      paths <- list()
      paths$trials <- export_pipeline_data(
        behavioral_classified,
        stage = "extracted",
        name = paste0(metadata$id, "_behavioral_trials"),
        base_dir = "output",
        formats = c("csv", "parquet")
      )
      # Export behavioral summary
      paths$summary <- export_pipeline_data(
        behavioral_summary,
        stage = "extracted",
        name = paste0(metadata$id, "_behavioral_summary"),
        base_dir = "output",
        formats = c("csv")
      )
      unlist(paths, use.names = FALSE)
    },
    format = "file"
  ),
  
  # Placeholder targets for future PR-B implementation
  # tar_target(offsets, compute_offsets(validation_df)),
  # tar_target(samples_adjusted, apply_offsets(samples_raw, offsets)),
  # tar_target(samples_resampled, resample_samples(samples_adjusted)),
  # ... more to come in PR-B
  
  # Summary report
  tar_target(
    pipeline_summary,
    {
      # Create summary
      summary <- tibble::tibble(
        participant = metadata$id,
        n_samples = nrow(samples_raw),
        n_events = nrow(events_raw),
        n_trials = metadata$n_trials,
        n_calibrations = sum(events_raw$type == "calibration"),
        n_signals = sum(events_raw$type == "signal"),
        n_responses = sum(events_raw$type == "response"),
        n_image_events = sum(events_raw$type %in% c("image_onset", "image_offset")),
        n_validations = nrow(validation_df),
        # Behavioral outcomes
        n_hits = behavioral_summary$n_hits,
        n_misses = behavioral_summary$n_misses,
        n_false_alarms = behavioral_summary$n_false_alarms,
        hit_rate = behavioral_summary$hit_rate,
        d_prime = behavioral_summary$d_prime,
        mean_rt = behavioral_summary$mean_rt,
        sampling_rate_hz = metadata$sampling_rate_hz,
        duration_sec = metadata$duration_ms / 1000
      )
      
      # Print summary
      cli::cli_h1("itrackvalr Pipeline Summary (PR-A)")
      cli::cli_alert_success("Participant: {summary$participant}")
      cli::cli_alert_success("Samples: {summary$n_samples} at {summary$sampling_rate_hz} Hz")
      cli::cli_alert_success("Events: {summary$n_events} total ({summary$n_calibrations} calibrations, {summary$n_signals} signals, {summary$n_responses} responses)")
      cli::cli_alert_success("Behavioral: {summary$n_hits} hits, {summary$n_misses} misses, {summary$n_false_alarms} FAs (d'={round(summary$d_prime, 2)})")
      cli::cli_alert_success("Validations: {summary$n_validations} parsed (pre + post)")
      
      summary
    }
  ),
  
  # Export manifest (final step - lists all exported files)
  tar_target(
    export_manifest,
    {
      # Ensure all exports complete first
      export_samples_raw
      export_events_raw
      export_validation_data
      export_behavioral_data
      
      # Create manifest
      create_export_manifest("output")
    }
  )
)

