# itrackvalr targets pipeline - Multi-Participant Processing
# Processes all participants and creates per-participant + aggregated datasets

library(targets)
library(tarchetypes)

# Source R functions
source("R/read_mat_data.R")
source("R/calibration.R")
source("R/behavioral.R")
source("R/export_helpers.R")
source("R/multi_participant.R")

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
  # === STEP 1: FIND ALL PARTICIPANTS ===
  
  tar_target(
    mat_files,
    get_mat_files("inst/extdata/synthetic")
  ),
  
  # === STEP 2: PROCESS ALL PARTICIPANTS ===
  
  tar_target(
    all_participant_data,
    read_all_participants(mat_files)
  ),
  
  # === STEP 3: AGGREGATE DATASETS ===
  
  tar_target(
    all_samples,
    aggregate_samples(all_participant_data)
  ),
  
  tar_target(
    all_events,
    aggregate_events(all_participant_data)
  ),
  
  tar_target(
    all_behavioral,
    aggregate_behavioral(all_participant_data)
  ),
  
  tar_target(
    all_validation,
    aggregate_validation(all_participant_data)
  ),
  
  tar_target(
    all_metadata,
    aggregate_metadata(all_participant_data)
  ),
  
  # === STEP 4: COHORT-LEVEL SUMMARIES ===
  
  tar_target(
    cohort_behavioral_summary,
    summarize_behavioral_by_participant(all_behavioral)
  ),
  
  tar_target(
    cohort_validation_summary,
    tryCatch(
      summarize_validation_relationships(all_validation),
      error = function(e) {
        cli::cli_warn("Validation summary skipped (constant data or n<3): {e$message}")
        NULL
      }
    )
  ),
  
  # === STEP 5: CREATE OUTPUT STRUCTURE ===
  
  tar_target(
    output_dirs,
    create_output_dirs("output")
  ),
  
  # === STEP 6: EXPORT AGGREGATED DATA ===
  
  tar_target(
    export_aggregated_datasets,
    {
      output_dirs  # Ensure directories exist
      
      files <- list()
      
      # Export aggregated samples (Parquet only - large file)
      cli::cli_alert_info("Exporting aggregated samples ({nrow(all_samples)} rows)...")
      files$samples <- export_pipeline_data(
        data = all_samples,
        stage = "extracted",
        name = "ALL_samples",
        base_dir = "output",
        formats = c("parquet")
      )
      
      # Export aggregated events (CSV + Parquet)
      cli::cli_alert_info("Exporting aggregated events ({nrow(all_events)} rows)...")
      files$events <- export_pipeline_data(
        data = all_events,
        stage = "extracted",
        name = "ALL_events",
        base_dir = "output",
        formats = c("csv", "parquet")
      )
      
      # Export aggregated behavioral (CSV + Parquet)
      cli::cli_alert_info("Exporting aggregated behavioral ({nrow(all_behavioral)} trials)...")
      files$behavioral <- export_pipeline_data(
        data = all_behavioral,
        stage = "extracted",
        name = "ALL_behavioral",
        base_dir = "output",
        formats = c("csv", "parquet")
      )
      
      # Export metadata
      cli::cli_alert_info("Exporting participant metadata ({nrow(all_metadata)} participants)...")
      files$metadata <- export_pipeline_data(
        data = all_metadata,
        stage = "extracted",
        name = "ALL_metadata",
        base_dir = "output",
        formats = c("csv")
      )
      
      # Export cohort summaries
      files$behav_summary <- export_pipeline_data(
        data = cohort_behavioral_summary,
        stage = "extracted",
        name = "cohort_behavioral_summary",
        base_dir = "output",
        formats = c("csv")
      )
      
      # Export validation summary (if available)
      if (!is.null(cohort_validation_summary)) {
        files$val_summary <- export_pipeline_data(
          data = cohort_validation_summary$global_summary,
          stage = "extracted",
          name = "cohort_validation_summary",
          base_dir = "output",
          formats = c("csv")
        )
      }
      
      unlist(files, use.names = FALSE)
    },
    format = "file"
  ),
  
  # === STEP 7: COHORT SUMMARY REPORT ===
  
  tar_target(
    cohort_summary,
    {
      summary <- tibble::tibble(
        n_participants = nrow(all_metadata),
        total_samples = nrow(all_samples),
        total_events = nrow(all_events),
        total_trials = nrow(all_behavioral),
        total_signals = sum(all_behavioral$signal_flag == 1),
        total_responses = sum(all_behavioral$response_flag == 1),
        mean_hit_rate = mean(cohort_behavioral_summary$hit_rate, na.rm = TRUE),
        mean_fa_rate = mean(cohort_behavioral_summary$false_alarm_rate, na.rm = TRUE),
        mean_d_prime = mean(cohort_behavioral_summary$d_prime, na.rm = TRUE),
        mean_rt = mean(cohort_behavioral_summary$mean_rt, na.rm = TRUE)
      )
      
      cli::cli_h1("itrackvalr Cohort Summary")
      cli::cli_alert_success("Participants: {summary$n_participants}")
      cli::cli_alert_success("Total samples: {summary$total_samples} ({summary$total_samples / summary$n_participants} per participant)")
      cli::cli_alert_success("Total trials: {summary$total_trials} ({summary$total_trials / summary$n_participants} per participant)")
      cli::cli_alert_success("Total signals: {summary$total_signals} ({round(summary$total_signals / summary$total_trials * 100, 1)}%)")
      cli::cli_alert_success("Cohort performance: Hit rate = {round(summary$mean_hit_rate * 100, 1)}%, FA rate = {round(summary$mean_fa_rate * 100, 1)}%, d' = {round(summary$mean_d_prime, 2)}")
      
      summary
    }
  ),
  
  # === STEP 8: EXPORT MANIFEST ===
  
  tar_target(
    export_manifest,
    {
      export_aggregated_datasets  # Ensure all exports complete
      create_export_manifest("output")
    }
  )
)
