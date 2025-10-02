#' Parse Validation Messages from Events
#'
#' @description
#' Extracts calibration and validation metrics from EyeLink validation messages.
#' Returns a tibble with pre-task and post-task average errors, maximum errors,
#' and pixel offsets.
#'
#' @param events_df A tibble of events (output from `read_mat_data()$events`)
#'   containing calibration messages.
#'
#' @return A tibble with one row per validation (pre and post), containing:
#'   - `id`: Participant identifier
#'   - `time`: Timestamp of validation message
#'   - `type`: "pre" or "post"
#'   - `avg_err_deg`: Average validation error in degrees
#'   - `max_err_deg`: Maximum validation error in degrees
#'   - `offset_x_px`: Horizontal offset in pixels
#'   - `offset_y_px`: Vertical offset in pixels
#'   - `raw_msg`: Original message string
#'
#' @examples
#' \dontrun{
#' mat_data <- read_mat_data("path/to/file.mat")
#' validation_df <- parse_validation_msgs(mat_data$events)
#' }
#'
#' @export
parse_validation_msgs <- function(events_df) {
  
  # Filter to calibration events only
  cal_events <- events_df |>
    dplyr::filter(type == "calibration")
  
  if (nrow(cal_events) == 0) {
    cli::cli_warn("No calibration events found in events data")
    return(tibble::tibble(
      id = character(),
      time = numeric(),
      type = character(),
      avg_err_deg = numeric(),
      max_err_deg = numeric(),
      offset_x_px = numeric(),
      offset_y_px = numeric(),
      raw_msg = character()
    ))
  }
  
  # Extract validation metrics
  validation_df <- cal_events |>
    dplyr::transmute(
      id = id,
      time = t,
      type = validation_type,
      avg_err_deg = avg_err_deg,
      max_err_deg = max_err_deg,
      offset_x_px = offset_x_px,
      offset_y_px = offset_y_px,
      raw_msg = msg
    ) |>
    dplyr::filter(!is.na(type))  # Only keep parsed validations
  
  if (nrow(validation_df) == 0) {
    cli::cli_warn("Calibration events found but validation metrics could not be parsed")
  } else {
    n_pre <- sum(validation_df$type == "pre", na.rm = TRUE)
    n_post <- sum(validation_df$type == "post", na.rm = TRUE)
    cli::cli_alert_info("Parsed {n_pre} pre-task and {n_post} post-task validation{?s}")
  }
  
  validation_df
}

#' Summarize Validation Relationships
#'
#' @description
#' Computes descriptive statistics and correlations between pre-task and
#' post-task validation errors across participants. This helps assess whether
#' calibration quality degrades over the session.
#'
#' @param validation_df Output from `parse_validation_msgs()`.
#'
#' @return A list containing:
#'   - `subject_summary`: Subject-level pre/post metrics
#'   - `global_summary`: Aggregated statistics across all subjects
#'   - `correlation`: Correlation between pre and post errors
#'   - `paired_test`: Paired t-test results for pre vs post
#'
#' @details
#' Per the specification, we examine validation data to:
#' 1. Assess stability across the session (pre vs post)
#' 2. Define zone of uncertainty from validation errors
#'
#' @examples
#' \dontrun{
#' validation_df <- parse_validation_msgs(events)
#' summary <- summarize_validation_relationships(validation_df)
#' }
#'
#' @export
summarize_validation_relationships <- function(validation_df) {
  
  # Reshape to wide format (one row per participant)
  wide_df <- validation_df |>
    tidyr::pivot_wider(
      id_cols = id,
      names_from = type,
      values_from = c(avg_err_deg, max_err_deg, offset_x_px, offset_y_px),
      names_sep = "_"
    )
  
  # Subject-level summary
  subject_summary <- wide_df
  
  # Global summary statistics
  global_summary <- tibble::tibble(
    metric = c("avg_err_deg", "max_err_deg", "offset_x_px", "offset_y_px"),
    pre_mean = c(
      mean(wide_df$avg_err_deg_pre, na.rm = TRUE),
      mean(wide_df$max_err_deg_pre, na.rm = TRUE),
      mean(wide_df$offset_x_px_pre, na.rm = TRUE),
      mean(wide_df$offset_y_px_pre, na.rm = TRUE)
    ),
    post_mean = c(
      mean(wide_df$avg_err_deg_post, na.rm = TRUE),
      mean(wide_df$max_err_deg_post, na.rm = TRUE),
      mean(wide_df$offset_x_px_post, na.rm = TRUE),
      mean(wide_df$offset_y_px_post, na.rm = TRUE)
    ),
    mean_diff = post_mean - pre_mean,
    sd_diff = c(
      sd(wide_df$avg_err_deg_post - wide_df$avg_err_deg_pre, na.rm = TRUE),
      sd(wide_df$max_err_deg_post - wide_df$max_err_deg_pre, na.rm = TRUE),
      sd(wide_df$offset_x_px_post - wide_df$offset_x_px_pre, na.rm = TRUE),
      sd(wide_df$offset_y_px_post - wide_df$offset_y_px_pre, na.rm = TRUE)
    )
  )
  
  # Correlation between pre and post average errors
  # Check for sufficient variation (need n > 2 AND variation in data)
  correlation <- if (nrow(wide_df) > 2 && 
                     sd(wide_df$avg_err_deg_pre, na.rm = TRUE) > 0 &&
                     sd(wide_df$avg_err_deg_post, na.rm = TRUE) > 0) {
    tryCatch(
      stats::cor.test(
        wide_df$avg_err_deg_pre,
        wide_df$avg_err_deg_post,
        method = "pearson"
      ),
      error = function(e) {
        cli::cli_warn("Could not compute correlation: {e$message}")
        NULL
      }
    )
  } else {
    NULL
  }
  
  # Paired t-test for pre vs post average error
  # Check for sufficient variation
  paired_test <- if (nrow(wide_df) > 2 &&
                     sd(wide_df$avg_err_deg_post - wide_df$avg_err_deg_pre, na.rm = TRUE) > 0) {
    tryCatch(
      stats::t.test(
        wide_df$avg_err_deg_post,
        wide_df$avg_err_deg_pre,
        paired = TRUE
      ),
      error = function(e) {
        cli::cli_warn("Could not compute paired t-test: {e$message}")
        NULL
      }
    )
  } else {
    NULL
  }
  
  list(
    subject_summary = subject_summary,
    global_summary = global_summary,
    correlation = correlation,
    paired_test = paired_test
  )
}

#' Convert visual angle (degrees) to pixels
#'
#' @description
#' Converts visual angle in degrees to pixel coordinates using screen
#' dimensions and viewing distance. Used for converting validation errors
#' from degrees to pixels for zone-of-uncertainty calculations.
#'
#' @param deg Visual angle in degrees
#' @param cfg Configuration list (from config::get()) containing screen parameters
#'
#' @return Numeric vector of pixel values
#'
#' @details
#' Formula: px = 2 * viewing_distance * tan(deg / 2) * (screen_px / screen_mm)
#'
#' Uses screen parameters from config.yml:
#' - `screen$viewing_distance_mm`: Distance from eyes to screen (650mm for remote mode)
#' - `screen$width_px` and `screen$width_mm`: Screen dimensions
#'
#' For horizontal distances, uses width parameters; for vertical, uses height.
#' This function uses width by default (most validation errors are reported
#' as single values, not separated by axis).
#'
#' @examples
#' \dontrun{
#' cfg <- config::get()
#' # Convert 1 degree of visual angle to pixels
#' deg_to_px(1.0, cfg)  # Returns ~36 pixels for typical remote setup
#' }
#'
#' @export
deg_to_px <- function(deg, cfg = config::get()) {
  
  # Extract screen parameters
  viewing_distance_mm <- cfg$screen$viewing_distance_mm
  width_px <- cfg$screen$width_px
  width_mm <- cfg$screen$width_mm
  
  # Validate parameters
  if (is.null(viewing_distance_mm) || is.null(width_px) || is.null(width_mm)) {
    cli::cli_abort(c(
      "Missing screen configuration parameters",
      "i" = "Ensure config.yml contains screen$viewing_distance_mm, screen$width_px, screen$width_mm"
    ))
  }
  
  # Convert degrees to radians
  rad <- deg * pi / 180
  
  # Calculate pixel distance
  # Formula: 2 * d * tan(θ/2) gives physical distance in mm
  # Then convert to pixels using px/mm ratio
  px <- 2 * viewing_distance_mm * tan(rad / 2) * (width_px / width_mm)
  
  px
}

#' Convert pixels to visual angle (degrees)
#'
#' @description
#' Converts pixel coordinates to visual angle in degrees using screen
#' dimensions and viewing distance. Inverse of deg_to_px().
#'
#' @param px Pixel distance
#' @param cfg Configuration list (from config::get()) containing screen parameters
#'
#' @return Numeric vector of visual angles in degrees
#'
#' @details
#' Formula: deg = 2 * atan(px * screen_mm / (2 * viewing_distance * screen_px)) * 180/π
#'
#' Uses same screen parameters as `deg_to_px()`. Useful for:
#' - Reporting gaze positions in standardized units
#' - Comparing metrics across different display setups
#' - Validation of calibration accuracy
#'
#' @examples
#' \dontrun{
#' cfg <- config::get()
#' # Convert 36 pixels to degrees
#' px_to_deg(36, cfg)  # Returns ~1.0 degree for typical remote setup
#' }
#'
#' @export
px_to_deg <- function(px, cfg = config::get()) {
  
  # Extract screen parameters
  viewing_distance_mm <- cfg$screen$viewing_distance_mm
  width_px <- cfg$screen$width_px
  width_mm <- cfg$screen$width_mm
  
  # Validate parameters
  if (is.null(viewing_distance_mm) || is.null(width_px) || is.null(width_mm)) {
    cli::cli_abort(c(
      "Missing screen configuration parameters",
      "i" = "Ensure config.yml contains screen$viewing_distance_mm, screen$width_px, screen$width_mm"
    ))
  }
  
  # Convert pixels to physical distance (mm)
  # Then convert to visual angle
  mm_distance <- px * (width_mm / width_px)
  rad <- 2 * atan(mm_distance / (2 * viewing_distance_mm))
  
  # Convert radians to degrees
  deg <- rad * 180 / pi
  
  deg
}

#' Apply calibration offsets to gaze coordinates
#'
#' @description
#' Adjusts gaze positions (x_px, y_px) based on calibration validation offsets.
#' Supports three methods: using pre-task offsets only, post-task offsets only,
#' or linear interpolation between pre and post offsets over time.
#'
#' @param samples_df A tibble or LazyFrame with gaze samples containing columns:
#'   id, t, x_px, y_px (and optionally other columns)
#' @param validation_df A tibble with validation data (from parse_validation_msgs)
#'   containing: id, type ("pre"/"post"), offset_x_px, offset_y_px
#' @param method Method for applying offsets:
#'   - "pre": Use pre-task offsets only (constant across session)
#'   - "post": Use post-task offsets only (constant across session)
#'   - "linear": Linear interpolation from pre to post over time (default)
#'
#' @return Same type as input (tibble or LazyFrame) with new columns:
#'   - x_px_adj: Calibration-adjusted x coordinate
#'   - y_px_adj: Calibration-adjusted y coordinate
#'   - offset_x_applied: Offset applied to x
#'   - offset_y_applied: Offset applied to y
#'
#' @details
#' Calibration offsets correct for systematic gaze position errors. The linear
#' interpolation method accounts for potential drift over the session duration.
#'
#' For participants missing validation data, no adjustment is applied and
#' adj columns equal original coordinates.
#'
#' This function supports both eager (tibble) and lazy (LazyFrame) processing.
#' For large datasets (>1M rows), use LazyFrame input for efficient memory usage.
#'
#' @examples
#' \dontrun{
#' # Eager processing (small datasets)
#' samples <- read_mat_data("file.mat")$samples
#' validation <- parse_validation_msgs(events)
#' samples_adj <- apply_calibration_offsets(samples, validation, method = "linear")
#'
#' # Lazy processing (large datasets)
#' samples_lf <- to_polars_lf(all_samples)
#' samples_adj_lf <- apply_calibration_offsets(samples_lf, validation, method = "linear")
#' sink_parquet(samples_adj_lf, "output/calibrated/ALL_samples.parquet")
#' }
#'
#' @export
apply_calibration_offsets <- function(samples_df,
                                      validation_df,
                                      method = c("linear", "pre", "post")) {
  
  method <- match.arg(method)
  
  # Detect if input is LazyFrame
  is_lazy <- inherits(samples_df, "polars_lazy_frame")
  
  # For lazy processing, convert validation to join-compatible format
  # and use tidypolars operations
  if (is_lazy) {
    return(apply_calibration_offsets_lazy(samples_df, validation_df, method))
  }
  
  # Eager processing path (tibbles)
  apply_calibration_offsets_eager(samples_df, validation_df, method)
}

#' Apply calibration offsets (eager tibble version)
#'
#' @keywords internal
apply_calibration_offsets_eager <- function(samples_df, validation_df, method) {
  
  # Get unique participants
  participant_ids <- unique(samples_df$id)
  
  # Prepare offset lookup
  offsets_wide <- validation_df |>
    tidyr::pivot_wider(
      id_cols = id,
      names_from = type,
      values_from = c(offset_x_px, offset_y_px),
      names_sep = "_"
    )
  
  # For each participant, compute offsets based on method
  samples_with_offsets <- samples_df |>
    dplyr::left_join(offsets_wide, by = "id")
  
  # Compute adjusted coordinates based on method
  if (method == "pre") {
    # Use pre-task offsets only
    samples_adjusted <- samples_with_offsets |>
      dplyr::mutate(
        offset_x_applied = dplyr::coalesce(.data$offset_x_px_pre, 0),
        offset_y_applied = dplyr::coalesce(.data$offset_y_px_pre, 0),
        x_px_adj = .data$x_px - .data$offset_x_applied,
        y_px_adj = .data$y_px - .data$offset_y_applied
      )
    
  } else if (method == "post") {
    # Use post-task offsets only
    samples_adjusted <- samples_with_offsets |>
      dplyr::mutate(
        offset_x_applied = dplyr::coalesce(.data$offset_x_px_post, 0),
        offset_y_applied = dplyr::coalesce(.data$offset_y_px_post, 0),
        x_px_adj = .data$x_px - .data$offset_x_applied,
        y_px_adj = .data$y_px - .data$offset_y_applied
      )
    
  } else {
    # Linear interpolation from pre to post
    # Need to get session duration for each participant
    session_info <- samples_df |>
      dplyr::group_by(.data$id) |>
      dplyr::summarise(
        t_min = min(.data$t, na.rm = TRUE),
        t_max = max(.data$t, na.rm = TRUE),
        duration = .data$t_max - .data$t_min,
        .groups = "drop"
      )
    
    samples_adjusted <- samples_with_offsets |>
      dplyr::left_join(session_info, by = "id") |>
      dplyr::mutate(
        # Interpolation weight: 0 at start (use pre), 1 at end (use post)
        interp_weight = ifelse(.data$duration > 0,
                               (.data$t - .data$t_min) / .data$duration,
                               0),
        # Interpolate offsets
        offset_x_applied = dplyr::coalesce(
          .data$offset_x_px_pre + .data$interp_weight * (.data$offset_x_px_post - .data$offset_x_px_pre),
          0
        ),
        offset_y_applied = dplyr::coalesce(
          .data$offset_y_px_pre + .data$interp_weight * (.data$offset_y_px_post - .data$offset_y_px_pre),
          0
        ),
        # Apply interpolated offsets
        x_px_adj = .data$x_px - .data$offset_x_applied,
        y_px_adj = .data$y_px - .data$offset_y_applied
      ) |>
      dplyr::select(-c("t_min", "t_max", "duration", "interp_weight"))
  }
  
  # Clean up intermediate columns
  samples_adjusted <- samples_adjusted |>
    dplyr::select(
      -dplyr::starts_with("offset_x_px"),
      -dplyr::starts_with("offset_y_px")
    )
  
  n_adjusted <- sum(!is.na(samples_adjusted$offset_x_applied))
  cli::cli_alert_success(
    "Applied {method} calibration offsets to {n_adjusted} sample{?s}"
  )
  
  samples_adjusted
}

#' Apply calibration offsets (lazy LazyFrame version)
#'
#' @keywords internal
apply_calibration_offsets_lazy <- function(samples_lf, validation_df, method) {
  
  if (!has_polars()) {
    cli::cli_abort(c(
      "tidypolars required for lazy processing",
      "i" = "Use eager tibble input or install tidypolars"
    ))
  }
  
  # For LazyFrame processing, we need to pivot the validation data first (as tibble)
  # then convert to LazyFrame (pivot_wider not supported on LazyFrames)
  offsets_wide <- validation_df |>
    tidyr::pivot_wider(
      id_cols = id,
      names_from = type,
      values_from = c(offset_x_px, offset_y_px),
      names_sep = "_"
    ) |>
    to_polars_lf()
  
  # Join offsets to samples
  samples_with_offsets <- samples_lf |>
    dplyr::left_join(offsets_wide, by = "id")
  
  # Compute adjusted coordinates (lazy operations)
  if (method == "pre") {
    samples_adjusted <- samples_with_offsets |>
      dplyr::mutate(
        offset_x_applied = dplyr::coalesce(.data$offset_x_px_pre, 0),
        offset_y_applied = dplyr::coalesce(.data$offset_y_px_pre, 0),
        x_px_adj = .data$x_px - .data$offset_x_applied,
        y_px_adj = .data$y_px - .data$offset_y_applied
      )
    
  } else if (method == "post") {
    samples_adjusted <- samples_with_offsets |>
      dplyr::mutate(
        offset_x_applied = dplyr::coalesce(.data$offset_x_px_post, 0),
        offset_y_applied = dplyr::coalesce(.data$offset_y_px_post, 0),
        x_px_adj = .data$x_px - .data$offset_x_applied,
        y_px_adj = .data$y_px - .data$offset_y_applied
      )
    
  } else {
    # Linear interpolation (lazy)
    # Compute session bounds per participant
    session_info <- samples_lf |>
      dplyr::group_by(.data$id) |>
      dplyr::summarise(
        t_min = min(.data$t),
        t_max = max(.data$t),
        duration = .data$t_max - .data$t_min
      ) |>
      dplyr::ungroup()
    
    samples_adjusted <- samples_with_offsets |>
      dplyr::left_join(session_info, by = "id") |>
      dplyr::mutate(
        # Interpolation weight
        interp_weight = dplyr::if_else(.data$duration > 0,
                                       (.data$t - .data$t_min) / .data$duration,
                                       0),
        # Interpolate offsets
        offset_x_applied = dplyr::coalesce(
          .data$offset_x_px_pre + .data$interp_weight * (.data$offset_x_px_post - .data$offset_x_px_pre),
          0
        ),
        offset_y_applied = dplyr::coalesce(
          .data$offset_y_px_pre + .data$interp_weight * (.data$offset_y_px_post - .data$offset_y_px_pre),
          0
        ),
        # Apply offsets
        x_px_adj = .data$x_px - .data$offset_x_applied,
        y_px_adj = .data$y_px - .data$offset_y_applied
      ) |>
      dplyr::select(-c(.data$t_min, .data$t_max, .data$duration, .data$interp_weight))
  }
  
  # Clean up intermediate columns
  samples_adjusted <- samples_adjusted |>
    dplyr::select(
      -dplyr::starts_with("offset_x_px"),
      -dplyr::starts_with("offset_y_px")
    )
  
  cli::cli_alert_success(
    "Configured {method} calibration offset application (lazy - not yet computed)"
  )
  
  samples_adjusted
}

#' Compute zone-of-uncertainty radius from validation errors
#'
#' @description
#' Calculates the radius (in pixels) of the zone of uncertainty around the
#' clock hand tip, based on calibration validation errors. This radius
#' defines the threshold for determining whether a gaze point is "on-task"
#' (looking at the clock hand) or "off-task".
#'
#' @param validation_df A tibble with validation data (from parse_validation_msgs)
#'   containing: id, type ("pre"/"post"), avg_err_deg, max_err_deg
#' @param strategy Strategy for computing radius:
#'   - "average": Use average validation error across pre/post (default)
#'   - "maximum": Use maximum validation error (conservative)
#'   - "pre_avg": Use only pre-task average error
#'   - "post_avg": Use only post-task average error
#' @param scaling Scaling factor to apply to the computed radius (default: 1.0)
#'   Values >1 make the zone more lenient, <1 more strict
#' @param cfg Configuration list (from config::get()) for deg_to_px conversion
#'
#' @return A tibble with columns:
#'   - id: Participant identifier
#'   - r_px: Zone radius in pixels
#'   - r_deg: Zone radius in degrees (before conversion)
#'   - strategy: Strategy used
#'   - scaling: Scaling factor applied
#'
#' @details
#' The zone of uncertainty represents the expected positional error in gaze
#' tracking. A larger zone is more lenient (more samples classified as on-task),
#' while a smaller zone is more strict.
#'
#' Typical values:
#' - Average error: ~0.5-1.5 degrees → ~18-54 pixels
#' - Maximum error: ~2-4 degrees → ~72-144 pixels
#'
#' For sensitivity analyses, vary the `scaling` parameter (e.g., 0.5, 1.0, 1.5)
#' to assess how zone size affects on-task estimates.
#'
#' @examples
#' \dontrun{
#' validation_df <- parse_validation_msgs(events)
#' zone_radii <- compute_zone_radius(validation_df, strategy = "average", scaling = 1.0)
#' # Use in binarization
#' samples_binarized <- binarize_on_task(samples, hand_positions, zone_radii)
#' }
#'
#' @export
compute_zone_radius <- function(validation_df,
                                strategy = c("average", "maximum", "pre_avg", "post_avg"),
                                scaling = 1.0,
                                cfg = config::get()) {
  
  strategy <- match.arg(strategy)
  
  # Validate scaling
  if (scaling <= 0) {
    cli::cli_abort("Scaling factor must be positive (got {scaling})")
  }
  
  # Prepare validation data in wide format
  validation_wide <- validation_df |>
    tidyr::pivot_wider(
      id_cols = id,
      names_from = type,
      values_from = c(avg_err_deg, max_err_deg),
      names_sep = "_"
    )
  
  # Compute radius in degrees based on strategy
  zone_df <- validation_wide |>
    dplyr::mutate(
      r_deg = dplyr::case_when(
        strategy == "average" ~ (
          (.data$avg_err_deg_pre + .data$avg_err_deg_post) / 2
        ),
        strategy == "maximum" ~ pmax(
          .data$max_err_deg_pre,
          .data$max_err_deg_post,
          na.rm = TRUE
        ),
        strategy == "pre_avg" ~ .data$avg_err_deg_pre,
        strategy == "post_avg" ~ .data$avg_err_deg_post,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::select(id, r_deg)
  
  # Convert to pixels and apply scaling
  zone_df <- zone_df |>
    dplyr::mutate(
      r_px = deg_to_px(.data$r_deg, cfg) * scaling,
      strategy = strategy,
      scaling = scaling
    )
  
  # Handle missing values
  n_missing <- sum(is.na(zone_df$r_px))
  if (n_missing > 0) {
    cli::cli_warn(
      "{n_missing} participant{?s} missing validation data; zone radius set to NA"
    )
  }
  
  # Report summary statistics
  r_px_mean <- mean(zone_df$r_px, na.rm = TRUE)
  r_px_sd <- sd(zone_df$r_px, na.rm = TRUE)
  
  cli::cli_alert_success(
    "Computed zone radii ({strategy}, scaling={scaling}): mean={round(r_px_mean, 1)} px (SD={round(r_px_sd, 1)})"
  )
  
  zone_df
}

