#' Gaze Data Resampling Functions
#'
#' Functions for resampling eye-tracking data to uniform time grids with
#' linear interpolation and gap detection.

#' Resample gaze samples to uniform grid (polars-optimized)
#'
#' @description
#' Resamples eye-tracking data to a uniform temporal grid using linear
#' interpolation. This standardizes variable-rate data (500-1000 Hz with gaps)
#' to a consistent frequency for downstream analyses.
#'
#' @param samples_df A tibble or LazyFrame with gaze samples containing:
#'   id, t (time in ms), x_px, y_px, pupil, and optionally x_px_adj, y_px_adj
#' @param hz_standard Target sampling rate in Hz (default: 500)
#' @param gap_threshold Maximum gap duration in ms before marking as missing (default: 20)
#'
#' @return Same type as input (tibble or LazyFrame) with resampled data.
#'   New columns:
#'   - t_resampled: Uniform grid timestamps
#'   - gap_flag: Logical indicating if interpolated across a gap
#'   Original columns are interpolated to the new grid
#'
#' @details
#' EyeLink 1000 Plus in remote mode samples at 500-1000 Hz but with
#' irregular intervals and gaps (blinks, tracker loss). Resampling:
#' 1. Creates uniform grid at target Hz (typically 500 Hz = 2 ms intervals)
#' 2. Linearly interpolates gaze coordinates and pupil size
#' 3. Marks gaps > threshold as missing (NA)
#' 4. Preserves participant grouping
#'
#' For large datasets (>1M rows), use LazyFrame input for efficient processing.
#' The function auto-detects input type and uses appropriate backend.
#'
#' @examples
#' \dontrun{
#' # Eager processing (small datasets)
#' samples <- read_mat_data("file.mat")$samples
#' samples_resampled <- resample_samples(samples, hz_standard = 500)
#'
#' # Lazy processing (large datasets)
#' samples_lf <- to_polars_lf(all_samples)
#' samples_resampled_lf <- resample_samples(samples_lf, hz_standard = 500)
#' }
#'
#' @export
resample_samples <- function(samples_df,
                             hz_standard = 500,
                             gap_threshold = 20) {
  
  # Detect if input is LazyFrame
  is_lazy <- inherits(samples_df, "polars_lazy_frame")
  
  if (is_lazy) {
    return(resample_samples_polars(samples_df, hz_standard, gap_threshold))
  }
  
  # Eager processing path
  resample_samples_eager(samples_df, hz_standard, gap_threshold)
}

#' Resample gaze samples (eager tibble version)
#'
#' @keywords internal
resample_samples_eager <- function(samples_df, hz_standard, gap_threshold) {
  
  # Time interval in ms
  interval_ms <- 1000 / hz_standard
  
  # Process each participant separately
  participant_ids <- unique(samples_df$id)
  
  resampled_list <- lapply(participant_ids, function(pid) {
    
    # Extract participant data
    p_samples <- samples_df |>
      dplyr::filter(.data$id == pid) |>
      dplyr::arrange(.data$t)
    
    if (nrow(p_samples) == 0) {
      return(NULL)
    }
    
    # Create uniform grid
    t_min <- min(p_samples$t, na.rm = TRUE)
    t_max <- max(p_samples$t, na.rm = TRUE)
    t_grid <- seq(t_min, t_max, by = interval_ms)
    
    # Detect gaps in original data
    p_samples <- p_samples |>
      dplyr::mutate(
        t_diff = dplyr::lead(.data$t) - .data$t,
        gap_flag = .data$t_diff > gap_threshold
      )
    
    # Interpolate each column
    grid_df <- tibble::tibble(
      id = pid,
      t = t_grid
    )
    
    # Columns to interpolate
    interp_cols <- c("x_px", "y_px", "pupil")
    if ("x_px_adj" %in% names(p_samples)) {
      interp_cols <- c(interp_cols, "x_px_adj", "y_px_adj")
    }
    
    # Linear interpolation using approx
    for (col in interp_cols) {
      grid_df[[col]] <- stats::approx(
        x = p_samples$t,
        y = p_samples[[col]],
        xout = t_grid,
        method = "linear",
        rule = 1  # NA outside range
      )$y
    }
    
    # Mark gaps: if any grid point falls in a gap, set to NA
    # Simple approach: identify which original samples have gaps
    gap_times <- p_samples$t[which(p_samples$gap_flag)]
    
    grid_df <- grid_df |>
      dplyr::mutate(
        gap_flag = vapply(.data$t, function(t_val) {
          # Check if this time point is within gap_threshold of a gap
          any(t_val > gap_times & t_val < (gap_times + gap_threshold))
        }, logical(1))
      )
    
    # Set interpolated values to NA within gaps
    for (col in interp_cols) {
      grid_df[[col]][grid_df$gap_flag] <- NA_real_
    }
    
    # Add eye column (always RIGHT)
    grid_df$eye <- "RIGHT"
    
    # Add blink flag (TRUE if pupil is NA or zero)
    grid_df <- grid_df |>
      dplyr::mutate(
        blink = is.na(.data$pupil) | .data$pupil == 0
      )
    
    grid_df
  })
  
  # Combine all participants
  resampled_df <- dplyr::bind_rows(resampled_list)
  
  n_orig <- nrow(samples_df)
  n_resampled <- nrow(resampled_df)
  
  cli::cli_alert_success(
    "Resampled {n_orig} samples to {n_resampled} samples at {hz_standard} Hz"
  )
  
  resampled_df
}

#' Resample gaze samples (lazy polars version)
#'
#' @keywords internal
resample_samples_polars <- function(samples_lf, hz_standard, gap_threshold) {
  
  if (!has_polars()) {
    cli::cli_abort(c(
      "tidypolars required for lazy resampling",
      "i" = "Use eager tibble input or install tidypolars"
    ))
  }
  
  # For polars, we need to materialize per-participant for interpolation
  # (interpolation requires ordered operations not well-suited to lazy eval)
  # However, we can process participants in batches and stream results
  
  cli::cli_alert_info(
    "Resampling with polars requires per-participant processing (interpolation not fully lazy)"
  )
  
  # Get list of participants from the LazyFrame
  # We need to materialize this small summary
  participant_ids <- samples_lf |>
    dplyr::distinct(.data$id) |>
    tidypolars::as_polars_df() |>
    tibble::as_tibble() |>
    dplyr::pull(.data$id)
  
  # Process each participant
  interval_ms <- 1000 / hz_standard
  
  resampled_list <- lapply(participant_ids, function(pid) {
    
    # Extract and materialize participant data (small enough to fit in memory)
    p_samples <- samples_lf |>
      dplyr::filter(.data$id == pid) |>
      dplyr::arrange(.data$t) |>
      tidypolars::as_polars_df() |>
      tibble::as_tibble()
    
    if (nrow(p_samples) == 0) {
      return(NULL)
    }
    
    # Use eager resampling logic for this participant
    # (Same as above but for single participant)
    t_min <- min(p_samples$t, na.rm = TRUE)
    t_max <- max(p_samples$t, na.rm = TRUE)
    t_grid <- seq(t_min, t_max, by = interval_ms)
    
    p_samples <- p_samples |>
      dplyr::mutate(
        t_diff = dplyr::lead(.data$t) - .data$t,
        gap_flag = .data$t_diff > gap_threshold
      )
    
    grid_df <- tibble::tibble(
      id = pid,
      t = t_grid
    )
    
    interp_cols <- c("x_px", "y_px", "pupil")
    if ("x_px_adj" %in% names(p_samples)) {
      interp_cols <- c(interp_cols, "x_px_adj", "y_px_adj")
    }
    
    for (col in interp_cols) {
      grid_df[[col]] <- stats::approx(
        x = p_samples$t,
        y = p_samples[[col]],
        xout = t_grid,
        method = "linear",
        rule = 1
      )$y
    }
    
    gap_times <- p_samples$t[which(p_samples$gap_flag)]
    
    grid_df <- grid_df |>
      dplyr::mutate(
        gap_flag = vapply(.data$t, function(t_val) {
          any(t_val > gap_times & t_val < (gap_times + gap_threshold))
        }, logical(1))
      )
    
    for (col in interp_cols) {
      grid_df[[col]][grid_df$gap_flag] <- NA_real_
    }
    
    grid_df$eye <- "RIGHT"
    grid_df <- grid_df |>
      dplyr::mutate(
        blink = is.na(.data$pupil) | .data$pupil == 0
      )
    
    grid_df
  })
  
  # Combine and convert back to LazyFrame
  resampled_df <- dplyr::bind_rows(resampled_list)
  resampled_lf <- to_polars_lf(resampled_df)
  
  n_resampled <- nrow(resampled_df)
  
  cli::cli_alert_success(
    "Resampled to {n_resampled} samples at {hz_standard} Hz (converting back to LazyFrame)"
  )
  
  resampled_lf
}

