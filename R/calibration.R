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

