#' Multi-Participant Data Processing Functions
#'
#' Functions to process multiple participants and aggregate data across the cohort

#' Get list of available .mat files
#'
#' @param data_dir Directory containing .mat files
#' @param pattern File pattern (default: ".mat$")
#'
#' @return Character vector of file paths
#' @export
get_mat_files <- function(data_dir = "inst/extdata/synthetic", pattern = "\\.mat$") {
  files <- list.files(data_dir, pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) {
    cli::cli_abort("No .mat files found in {.path {data_dir}}")
  }
  
  cli::cli_alert_info("Found {length(files)} .mat file{?s} in {.path {data_dir}}")
  files
}

#' Read and process multiple participants
#'
#' @param mat_files Character vector of .mat file paths
#'
#' @return A list with aggregated data across all participants
#' @export
read_all_participants <- function(mat_files) {
  
  cli::cli_alert_info("Processing {length(mat_files)} participant{?s}...")
  
  # Process each participant
  all_data <- lapply(mat_files, function(mat_file) {
    tryCatch(
      read_mat_data(mat_file),
      error = function(e) {
        cli::cli_alert_danger("Failed to read {.file {basename(mat_file)}}: {e$message}")
        NULL
      }
    )
  })
  
  # Remove NULL entries (failed reads)
  all_data <- Filter(Negate(is.null), all_data)
  
  if (length(all_data) == 0) {
    cli::cli_abort("No participants could be successfully processed")
  }
  
  cli::cli_alert_success("Successfully processed {length(all_data)} participant{?s}")
  
  all_data
}

#' Aggregate samples across participants
#'
#' @param participant_list List of participant data (from read_all_participants)
#'
#' @return Single tibble with all participants' samples combined
#' @export
aggregate_samples <- function(participant_list) {
  
  samples_list <- lapply(participant_list, function(p) p$samples)
  
  # Combine all samples
  all_samples <- dplyr::bind_rows(samples_list)
  
  cli::cli_alert_success("Aggregated {nrow(all_samples)} samples from {length(participant_list)} participant{?s}")
  
  all_samples
}

#' Aggregate events across participants
#'
#' @param participant_list List of participant data
#'
#' @return Single tibble with all participants' events combined
#' @export
aggregate_events <- function(participant_list) {
  
  events_list <- lapply(participant_list, function(p) p$events)
  all_events <- dplyr::bind_rows(events_list)
  
  cli::cli_alert_success("Aggregated {nrow(all_events)} events from {length(participant_list)} participant{?s}")
  
  all_events
}

#' Aggregate behavioral data across participants
#'
#' @param participant_list List of participant data
#'
#' @return Single tibble with all participants' behavioral trials combined
#' @export
aggregate_behavioral <- function(participant_list) {
  
  behavioral_list <- lapply(participant_list, function(p) {
    if (!is.null(p$behavioral)) p$behavioral else NULL
  })
  
  behavioral_list <- Filter(Negate(is.null), behavioral_list)
  
  if (length(behavioral_list) == 0) {
    cli::cli_warn("No behavioral data available to aggregate")
    return(tibble::tibble())
  }
  
  all_behavioral <- dplyr::bind_rows(behavioral_list)
  
  cli::cli_alert_success("Aggregated {nrow(all_behavioral)} trials from {length(behavioral_list)} participant{?s}")
  
  all_behavioral
}

#' Aggregate validation data across participants
#'
#' @param participant_list List of participant data
#'
#' @return Single tibble with all participants' validation metrics combined
#' @export
aggregate_validation <- function(participant_list) {
  
  # Extract events and parse validation from each
  validation_list <- lapply(participant_list, function(p) {
    parse_validation_msgs(p$events)
  })
  
  all_validation <- dplyr::bind_rows(validation_list)
  
  cli::cli_alert_success("Aggregated {nrow(all_validation)} validation message{?s} from {length(participant_list)} participant{?s}")
  
  all_validation
}

#' Aggregate metadata across participants
#'
#' @param participant_list List of participant data
#'
#' @return Single tibble with all participants' metadata combined
#' @export
aggregate_metadata <- function(participant_list) {
  
  metadata_list <- lapply(participant_list, function(p) p$metadata)
  all_metadata <- dplyr::bind_rows(metadata_list)
  
  cli::cli_alert_success("Aggregated metadata from {nrow(all_metadata)} participant{?s}")
  
  all_metadata
}

#' Compute cohort-level behavioral summary
#'
#' @param behavioral_df Aggregated behavioral data (from aggregate_behavioral)
#'
#' @return Tibble with one row per participant containing summary statistics
#' @export
summarize_behavioral_by_participant <- function(behavioral_df) {
  
  # Ensure outcomes are classified
  if (!"outcome" %in% names(behavioral_df)) {
    behavioral_df <- classify_behavioral_outcomes(behavioral_df)
  }
  
  # Group by participant and summarize
  behavioral_df |>
    dplyr::group_by(id) |>
    dplyr::summarise(
      n_trials = dplyr::n(),
      n_signal_trials = sum(signal_flag == 1),
      n_hits = sum(outcome == "hit", na.rm = TRUE),
      n_misses = sum(outcome == "miss", na.rm = TRUE),
      n_false_alarms = sum(outcome == "false_alarm", na.rm = TRUE),
      n_correct_rejections = sum(outcome == "correct_rejection", na.rm = TRUE),
      hit_rate = n_hits / n_signal_trials,
      false_alarm_rate = n_false_alarms / (n_trials - n_signal_trials),
      # d-prime with adjustment
      d_prime = qnorm((n_hits + 0.5) / (n_signal_trials + 1)) - 
                qnorm((n_false_alarms + 0.5) / (n_trials - n_signal_trials + 1)),
      criterion = -0.5 * (qnorm((n_hits + 0.5) / (n_signal_trials + 1)) + 
                          qnorm((n_false_alarms + 0.5) / (n_trials - n_signal_trials + 1))),
      # Reaction times for hits
      mean_rt = mean(reaction_time[outcome == "hit"], na.rm = TRUE),
      median_rt = median(reaction_time[outcome == "hit"], na.rm = TRUE),
      sd_rt = sd(reaction_time[outcome == "hit"], na.rm = TRUE),
      .groups = "drop"
    )
}

#' Export per-participant data files
#'
#' @param participant_list List of participant data
#' @param base_dir Base output directory
#' @param stage Pipeline stage ("raw", "extracted", etc.)
#'
#' @return List of file paths for each participant
#' @export
export_per_participant <- function(participant_list, base_dir = "output", stage = "extracted") {
  
  exported_files <- list()
  
  for (p_data in participant_list) {
    participant_id <- p_data$metadata$id
    
    # Export samples
    samples_files <- export_samples(p_data$samples, p_data$metadata, stage, base_dir)
    
    # Export events  
    events_files <- export_events(p_data$events, p_data$metadata, stage, base_dir)
    
    # Export behavioral if available
    if (!is.null(p_data$behavioral)) {
      behavioral_files <- export_pipeline_data(
        data = p_data$behavioral,
        stage = stage,
        name = paste0(participant_id, "_behavioral"),
        base_dir = base_dir,
        formats = c("csv", "parquet")
      )
      exported_files[[participant_id]] <- c(
        samples = samples_files,
        events = events_files,
        behavioral = unlist(behavioral_files)
      )
    } else {
      exported_files[[participant_id]] <- c(
        samples = samples_files,
        events = events_files
      )
    }
  }
  
  cli::cli_alert_success("Exported data for {length(exported_files)} participant{?s}")
  
  invisible(exported_files)
}

#' Export aggregated multi-participant datasets
#'
#' @param all_samples Aggregated samples tibble
#' @param all_events Aggregated events tibble
#' @param all_behavioral Aggregated behavioral tibble
#' @param all_metadata Aggregated metadata tibble
#' @param base_dir Base output directory
#' @param stage Pipeline stage
#'
#' @return List of exported file paths
#' @export
export_aggregated_data <- function(all_samples, 
                                    all_events, 
                                    all_behavioral, 
                                    all_metadata,
                                    base_dir = "output",
                                    stage = "extracted") {
  
  files <- list()
  
  # Export aggregated samples
  cli::cli_alert_info("Exporting aggregated samples ({nrow(all_samples)} rows)...")
  files$samples <- export_pipeline_data(
    data = all_samples,
    stage = stage,
    name = "ALL_samples",
    base_dir = base_dir,
    formats = c("parquet")  # Only Parquet for large aggregated file
  )
  
  # Export aggregated events
  cli::cli_alert_info("Exporting aggregated events ({nrow(all_events)} rows)...")
  files$events <- export_pipeline_data(
    data = all_events,
    stage = stage,
    name = "ALL_events",
    base_dir = base_dir,
    formats = c("csv", "parquet")
  )
  
  # Export aggregated behavioral
  if (nrow(all_behavioral) > 0) {
    cli::cli_alert_info("Exporting aggregated behavioral ({nrow(all_behavioral)} trials)...")
    files$behavioral <- export_pipeline_data(
      data = all_behavioral,
      stage = stage,
      name = "ALL_behavioral",
      base_dir = base_dir,
      formats = c("csv", "parquet")
    )
  }
  
  # Export metadata
  cli::cli_alert_info("Exporting participant metadata ({nrow(all_metadata)} participants)...")
  files$metadata <- export_pipeline_data(
    data = all_metadata,
    stage = stage,
    name = "ALL_metadata",
    base_dir = base_dir,
    formats = c("csv")
  )
  
  invisible(files)
}

