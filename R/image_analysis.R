#' Image Content Analysis Integration
#'
#' Functions for merging eye-tracking data with image analysis outputs
#' from the csn-image-analysis repository (arousal, valence, categories)

#' Join image content attributes to trial data
#'
#' @description
#' Merges trial-segmented eye-tracking data with image analysis outputs
#' (arousal, valence, content categories) produced by the csn-image-analysis
#' repository using shlab.imgct.
#'
#' @param trials_df A tibble with trial-segmented data (from segment_trials)
#'   containing: id, trial, image_index, and gaze metrics
#' @param image_analysis_df A tibble with image analysis results containing:
#'   - image_id or image_index: Image identifier (matches trial data)
#'   - arousal: Arousal rating (numeric)
#'   - valence: Valence rating (numeric)
#'   - category: Content category (character/factor)
#'   - (other optional attributes)
#' @param mismatch_tolerance Maximum proportion of trials allowed to have
#'   missing image data (default: 0.01 = 1%)
#'
#' @return A tibble with trial data augmented with image attributes:
#'   - arousal: Image arousal rating
#'   - valence: Image valence rating
#'   - category: Image content category
#'   - (all original trial columns)
#'
#' @details
#' Image analysis attributes enable stratified analyses of on-task behavior:
#' - **Arousal tertiles**: Low, medium, high arousal images
#' - **Valence bands**: Negative, neutral, positive valence
#' - **Content categories**: e.g., faces, scenes, objects
#'
#' The function enforces a mismatch tolerance: if more than `mismatch_tolerance`
#' proportion of trials lack image data, it errors out (suggesting data quality
#' issues). Missing image data could indicate:
#' - Image index mismatch between behavioral and image analysis
#' - Incomplete image analysis processing
#' - Image set version differences
#'
#' @examples
#' \dontrun{
#' # Load image analysis results
#' image_data <- readr::read_csv("path/to/image_analysis.csv")
#'
#' # Join to trials
#' trials_with_images <- join_image_content(
#'   trials,
#'   image_data,
#'   mismatch_tolerance = 0.01
#' )
#'
#' # Analyze by arousal tertile
#' trials_with_images |>
#'   mutate(arousal_tertile = ntile(arousal, 3)) |>
#'   group_by(arousal_tertile, t_trial_ms) |>
#'   summarize(p_on_task = mean(on_task, na.rm = TRUE))
#' }
#'
#' @export
join_image_content <- function(trials_df,
                               image_analysis_df,
                               mismatch_tolerance = 0.01) {
  
  # Standardize image identifier column name
  if ("image_id" %in% names(image_analysis_df) && 
      !"image_index" %in% names(image_analysis_df)) {
    image_analysis_df <- image_analysis_df |>
      dplyr::rename(image_index = .data$image_id)
  }
  
  # Validate required columns
  required_trial_cols <- c("id", "trial", "image_index")
  missing_trial_cols <- setdiff(required_trial_cols, names(trials_df))
  if (length(missing_trial_cols) > 0) {
    cli::cli_abort(c(
      "Trial data missing required columns",
      "x" = "Missing: {.field {missing_trial_cols}}"
    ))
  }
  
  required_image_cols <- c("image_index")
  missing_image_cols <- setdiff(required_image_cols, names(image_analysis_df))
  if (length(missing_image_cols) > 0) {
    cli::cli_abort(c(
      "Image analysis data missing required columns",
      "x" = "Missing: {.field {missing_image_cols}}",
      "i" = "Expected: image_index (or image_id), arousal, valence, category"
    ))
  }
  
  # Join image data to trials
  trials_with_images <- trials_df |>
    dplyr::left_join(
      image_analysis_df,
      by = "image_index",
      suffix = c("", "_img")
    )
  
  # Check for mismatches
  n_trials <- nrow(trials_df |> 
                     dplyr::distinct(.data$id, .data$trial))
  
  # Count matched trials (those with at least one image attribute)
  # Check if arousal or valence columns exist
  has_arousal <- "arousal" %in% names(trials_with_images)
  has_valence <- "valence" %in% names(trials_with_images)
  
  if (has_arousal || has_valence) {
    n_matched <- trials_with_images |>
      dplyr::filter(
        if (has_arousal && has_valence) {
          !is.na(arousal) | !is.na(valence)
        } else if (has_arousal) {
          !is.na(arousal)
        } else {
          !is.na(valence)
        }
      ) |>
      dplyr::distinct(id, trial) |>
      nrow()
  } else {
    n_matched <- 0
  }
  
  mismatch_proportion <- (n_trials - n_matched) / n_trials
  
  if (mismatch_proportion > mismatch_tolerance) {
    cli::cli_abort(c(
      "Image data mismatch exceeds tolerance",
      "x" = "{round(mismatch_proportion * 100, 1)}% of trials lack image data (tolerance: {mismatch_tolerance * 100}%)",
      "i" = "Matched: {n_matched}/{n_trials} trials",
      "i" = "Check that image_index values align between behavioral and image analysis data"
    ))
  }
  
  if (mismatch_proportion > 0) {
    cli::cli_warn(
      "{round(mismatch_proportion * 100, 2)}% of trials lack image data ({n_trials - n_matched}/{n_trials} trials)"
    )
  }
  
  # Report successful join
  image_cols <- setdiff(names(image_analysis_df), "image_index")
  
  cli::cli_alert_success(
    "Joined image attributes ({paste(image_cols, collapse = ', ')}) to {n_matched} trials"
  )
  
  trials_with_images
}

