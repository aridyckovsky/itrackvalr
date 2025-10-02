#' Preprocessing Functions for On-Task Classification
#'
#' Functions for computing distance to clock hand tip and binarizing
#' gaze into on-task/off-task indicators

#' Compute Euclidean distance from gaze to clock hand tip
#'
#' @description
#' Calculates the pixel distance from each gaze point to the clock hand tip
#' position at that moment. This distance is used with the zone-of-uncertainty
#' radius to classify gaze as on-task or off-task.
#'
#' @param samples_df A tibble or LazyFrame with gaze samples containing:
#'   id, t, x_px, y_px (or x_px_adj, y_px_adj if calibrated),
#'   tip_x_px, tip_y_px (from join_hand_positions)
#' @param use_adjusted If TRUE, use calibration-adjusted coordinates
#'   (x_px_adj, y_px_adj) if available; if FALSE, use raw coordinates (default: TRUE)
#'
#' @return Same type as input with added column:
#'   - dist_to_tip_px: Euclidean distance to hand tip in pixels
#'
#' @details
#' Distance formula: sqrt((x_gaze - x_tip)^2 + (y_gaze - y_tip)^2)
#'
#' For calibrated data, uses adjusted coordinates (x_px_adj, y_px_adj) which
#' correct for systematic tracker errors. Falls back to raw coordinates if
#' adjusted coordinates are not available.
#'
#' This function supports both eager (tibble) and lazy (LazyFrame) processing
#' for efficient handling of large datasets.
#'
#' @examples
#' \dontrun{
#' # After joining hand positions
#' samples_with_distance <- compute_distance(samples_with_hand)
#' }
#'
#' @export
compute_distance <- function(samples_df, use_adjusted = TRUE) {
  
  # Detect if input is LazyFrame
  is_lazy <- inherits(samples_df, "polars_lazy_frame")
  
  if (is_lazy) {
    return(compute_distance_polars(samples_df, use_adjusted))
  }
  
  # Eager processing
  compute_distance_eager(samples_df, use_adjusted)
}

#' Compute distance (eager tibble version)
#'
#' @keywords internal
compute_distance_eager <- function(samples_df, use_adjusted) {
  
  # Determine which coordinates to use
  has_adjusted <- "x_px_adj" %in% names(samples_df) && 
                  "y_px_adj" %in% names(samples_df)
  
  if (use_adjusted && !has_adjusted) {
    cli::cli_warn(
      "Adjusted coordinates requested but not found; using raw coordinates"
    )
  }
  
  use_adj <- use_adjusted && has_adjusted
  
  # Compute Euclidean distance
  samples_with_dist <- samples_df |>
    dplyr::mutate(
      # Select appropriate coordinates
      x_gaze = if (use_adj) .data$x_px_adj else .data$x_px,
      y_gaze = if (use_adj) .data$y_px_adj else .data$y_px,
      # Compute distance
      dist_to_tip_px = sqrt(
        (.data$x_gaze - .data$tip_x_px)^2 + 
        (.data$y_gaze - .data$tip_y_px)^2
      )
    ) |>
    dplyr::select(-"x_gaze", -"y_gaze")
  
  n_computed <- sum(!is.na(samples_with_dist$dist_to_tip_px))
  
  cli::cli_alert_success(
    "Computed distance to tip for {n_computed} sample{?s}"
  )
  
  samples_with_dist
}

#' Compute distance (lazy polars version)
#'
#' @keywords internal
compute_distance_polars <- function(samples_lf, use_adjusted) {
  
  if (!has_polars()) {
    cli::cli_abort(c(
      "tidypolars required for lazy processing",
      "i" = "Use eager tibble input or install tidypolars"
    ))
  }
  
  # Check for adjusted coordinates (need to peek at schema)
  # For LazyFrame, we'll attempt to use adjusted if requested
  # The mutate will handle missing columns gracefully
  
  samples_with_dist <- samples_lf |>
    dplyr::mutate(
      # Conditional coordinate selection
      # If adjusted requested and available, use those; otherwise raw
      dist_to_tip_px = sqrt(
        (dplyr::if_else(
          use_adjusted & !is.na(.data$x_px_adj), 
          .data$x_px_adj, 
          .data$x_px
        ) - .data$tip_x_px)^2 +
        (dplyr::if_else(
          use_adjusted & !is.na(.data$y_px_adj),
          .data$y_px_adj,
          .data$y_px
        ) - .data$tip_y_px)^2
      )
    )
  
  cli::cli_alert_success(
    "Configured distance computation (lazy - not yet computed)"
  )
  
  samples_with_dist
}

#' Binarize gaze into on-task/off-task indicators
#'
#' @description
#' Classifies each gaze sample as on-task (looking at clock hand) or off-task
#' based on distance to hand tip and zone-of-uncertainty radius. Handles blinks
#' and missing data appropriately.
#'
#' @param samples_df A tibble or LazyFrame with samples containing:
#'   id, dist_to_tip_px, blink (from compute_distance output)
#' @param zone_radii_df A tibble with zone radii per participant (from compute_zone_radius):
#'   id, r_px
#'
#' @return Same type as input with added column:
#'   - on_task: Logical indicating if gaze is on-task
#'     (TRUE = within zone, FALSE = outside zone, NA = blink or missing)
#'
#' @details
#' Classification logic:
#' - **on_task = TRUE**: dist_to_tip_px <= r_px (within zone of uncertainty)
#' - **on_task = FALSE**: dist_to_tip_px > r_px (outside zone)
#' - **on_task = NA**: blink == TRUE OR missing distance OR missing radius
#'
#' The zone radius represents expected tracker error. A more lenient zone
#' (larger r_px) classifies more samples as on-task; a stricter zone
#' classifies fewer.
#'
#' For sensitivity analyses, run with different zone_radii (varying scaling
#' factors) to assess robustness of on-task estimates.
#'
#' @examples
#' \dontrun{
#' zone_radii <- compute_zone_radius(validation_df, strategy = "average")
#' samples_binarized <- binarize_on_task(samples_with_distance, zone_radii)
#'
#' # Check on-task proportion
#' mean(samples_binarized$on_task, na.rm = TRUE)
#' }
#'
#' @export
binarize_on_task <- function(samples_df, zone_radii_df) {
  
  # Detect if input is LazyFrame
  is_lazy <- inherits(samples_df, "polars_lazy_frame")
  
  if (is_lazy) {
    return(binarize_on_task_polars(samples_df, zone_radii_df))
  }
  
  # Eager processing
  binarize_on_task_eager(samples_df, zone_radii_df)
}

#' Binarize on-task (eager tibble version)
#'
#' @keywords internal
binarize_on_task_eager <- function(samples_df, zone_radii_df) {
  
  # Join zone radii to samples
  samples_with_zone <- samples_df |>
    dplyr::left_join(
      zone_radii_df |> dplyr::select(id, r_px),
      by = "id"
    )
  
  # Classify as on-task
  samples_binarized <- samples_with_zone |>
    dplyr::mutate(
      on_task = dplyr::case_when(
        # Blinks are NA
        .data$blink == TRUE ~ NA,
        # Missing distance or radius are NA
        is.na(.data$dist_to_tip_px) | is.na(.data$r_px) ~ NA,
        # Within zone is TRUE
        .data$dist_to_tip_px <= .data$r_px ~ TRUE,
        # Outside zone is FALSE
        .data$dist_to_tip_px > .data$r_px ~ FALSE,
        # Default fallback
        TRUE ~ NA
      )
    ) |>
    dplyr::select(-"r_px")  # Remove temporary radius column
  
  # Report statistics
  n_on_task <- sum(samples_binarized$on_task == TRUE, na.rm = TRUE)
  n_off_task <- sum(samples_binarized$on_task == FALSE, na.rm = TRUE)
  n_missing <- sum(is.na(samples_binarized$on_task))
  prop_on_task <- n_on_task / (n_on_task + n_off_task)
  
  cli::cli_alert_success(
    "Binarized {nrow(samples_binarized)} samples: {round(prop_on_task * 100, 1)}% on-task ({n_missing} NA)"
  )
  
  samples_binarized
}

#' Binarize on-task (lazy polars version)
#'
#' @keywords internal
binarize_on_task_polars <- function(samples_lf, zone_radii_df) {
  
  if (!has_polars()) {
    cli::cli_abort(c(
      "tidypolars required for lazy processing",
      "i" = "Use eager tibble input or install tidypolars"
    ))
  }
  
  # Convert zone radii to LazyFrame for joining
  zone_radii_lf <- to_polars_lf(zone_radii_df |> dplyr::select(id, r_px))
  
  # Join and binarize (all lazy operations)
  samples_binarized <- samples_lf |>
    dplyr::left_join(zone_radii_lf, by = "id") |>
    dplyr::mutate(
      on_task = dplyr::case_when(
        .data$blink == TRUE ~ NA,
        is.na(.data$dist_to_tip_px) | is.na(.data$r_px) ~ NA,
        .data$dist_to_tip_px <= .data$r_px ~ TRUE,
        .data$dist_to_tip_px > .data$r_px ~ FALSE,
        TRUE ~ NA
      )
    ) |>
    dplyr::select(-"r_px")
  
  cli::cli_alert_success(
    "Configured on-task binarization (lazy - not yet computed)"
  )
  
  samples_binarized
}

#' Segment binarized data into image-presentation trials
#'
#' @description
#' Slices binarized gaze data into trials based on image onset/offset events.
#' Each trial includes all gaze samples during that image presentation period,
#' with time normalized relative to trial start.
#'
#' @param samples_df A tibble (not LazyFrame - this requires materialization)
#'   with binarized samples containing: id, t, on_task, and other columns
#' @param events_df A tibble with events containing image_onset and image_offset
#' @param behavioral_df A tibble with trial-level behavioral data containing:
#'   id, trial, image_index, task_begin, task_end
#'
#' @return A tibble with columns:
#'   - id: Participant identifier
#'   - trial: Trial number
#'   - t_trial_ms: Time within trial (0 = image onset)
#'   - t_absolute: Absolute timestamp
#'   - on_task: On-task indicator
#'   - image_index: Which image was presented
#'   - (all other columns from samples_df)
#'
#' @details
#' Trial segmentation:
#' 1. Extract image_onset and image_offset events
#' 2. For each trial, select samples between onset and offset
#' 3. Normalize time to trial start (t_trial_ms = 0 at onset)
#' 4. Join trial metadata (image_index, behavioral outcomes)
#'
#' This enables trial-level analyses and timecourse plots relative to
#' image onset (e.g., p(on-task) from 0-1000 ms post-onset).
#'
#' **Note**: This function requires materialized data (not LazyFrame) because
#' trial segmentation involves complex per-trial operations. If input is a
#' LazyFrame, it will be computed to tibble first.
#'
#' @examples
#' \dontrun{
#' samples_binarized <- binarize_on_task(samples, zone_radii)
#' trials <- segment_trials(samples_binarized, events, behavioral)
#'
#' # Analyze on-task timecourse per trial
#' trials |>
#'   group_by(trial, t_trial_ms) |>
#'   summarize(p_on_task = mean(on_task, na.rm = TRUE))
#' }
#'
#' @export
segment_trials <- function(samples_df, events_df, behavioral_df) {
  
  # Materialize if LazyFrame
  if (inherits(samples_df, "polars_lazy_frame")) {
    cli::cli_alert_info("Materializing LazyFrame for trial segmentation")
    samples_df <- to_tibble(samples_df)
  }
  
  # Get unique participants
  participant_ids <- unique(samples_df$id)
  
  # Segment each participant's data
  trial_segments_list <- lapply(participant_ids, function(pid) {
    
    # Extract participant data
    p_samples <- samples_df |>
      dplyr::filter(.data$id == pid) |>
      dplyr::arrange(.data$t)
    
    p_behavioral <- behavioral_df |>
      dplyr::filter(.data$id == pid) |>
      dplyr::arrange(.data$trial)
    
    p_events <- events_df |>
      dplyr::filter(.data$id == pid)
    
    if (nrow(p_behavioral) == 0) {
      cli::cli_warn("No behavioral data for participant {pid}; skipping")
      return(NULL)
    }
    
    # Extract image onset/offset events to define trial boundaries
    image_onsets <- p_events |>
      dplyr::filter(.data$type == "image_onset") |>
      dplyr::arrange(.data$t) |>
      dplyr::pull(.data$t)
    
    image_offsets <- p_events |>
      dplyr::filter(.data$type == "image_offset") |>
      dplyr::arrange(.data$t) |>
      dplyr::pull(.data$t)
    
    # Ensure we have matching onset/offset pairs
    n_pairs <- min(length(image_onsets), length(image_offsets))
    
    if (n_pairs == 0) {
      cli::cli_warn("No image onset/offset events for participant {pid}")
      return(NULL)
    }
    
    # For each trial, extract samples between onset and offset
    trial_list <- lapply(seq_len(min(n_pairs, nrow(p_behavioral))), function(i) {
      
      trial_info <- p_behavioral[i, ]
      trial_onset <- image_onsets[i]
      trial_offset <- image_offsets[i]
      
      # Extract samples within trial window (onset to offset)
      trial_samples <- p_samples |>
        dplyr::filter(
          .data$t >= trial_onset,
          .data$t <= trial_offset
        )
      
      if (nrow(trial_samples) == 0) {
        return(NULL)
      }
      
      # Add trial metadata and normalize time
      trial_samples |>
        dplyr::mutate(
          trial = trial_info$trial,
          image_index = trial_info$image_index,
          t_absolute = .data$t,
          t_trial_ms = .data$t - trial_onset,  # Normalize to trial start
          # Add behavioral outcomes for easy access
          signal_flag = trial_info$signal_flag,
          response_flag = trial_info$response_flag,
          outcome = if ("outcome" %in% names(trial_info)) trial_info$outcome else NA_character_
        )
    })
    
    # Combine trials for this participant
    dplyr::bind_rows(trial_list)
  })
  
  # Combine all participants
  all_trials <- dplyr::bind_rows(trial_segments_list)
  
  # Remove NULL entries
  all_trials <- all_trials |>
    dplyr::filter(!is.na(.data$trial))
  
  n_trials <- length(unique(paste(all_trials$id, all_trials$trial)))
  n_participants <- length(unique(all_trials$id))
  
  cli::cli_alert_success(
    "Segmented {nrow(all_trials)} samples into {n_trials} trials from {n_participants} participant{?s}"
  )
  
  all_trials
}


