#' Extract Trial-Level Behavioral Data
#'
#' @description
#' Creates a trial-level behavioral dataframe from subjdata, with one row per
#' trial containing all behavioral information: signals, responses, images, etc.
#' This is distinct from the events stream and is needed for behavioral analyses.
#'
#' @param subjdata The subjdata structure from .mat file (after [,,1] extraction)
#' @param participant_id Participant identifier
#'
#' @return A tibble with one row per trial containing:
#'   - `trial`: Trial number (1 to nTrials)
#'   - `id`: Participant identifier
#'   - `p_signal`: Probability of signal trials (session constant)
#'   - `clock_side`: 0 (left) or 1 (right) - session constant
#'   - `signal_flag`: 1 if signal occurred this trial, 0 otherwise
#'   - `signal_time`: Time of signal in ms (or NA if no signal)
#'   - `response_flag`: 1 if participant responded this trial, 0 otherwise
#'   - `response_time`: Time of response in ms (or NA if no response)
#'   - `image_index`: Which image was shown (1-10 for synthetic, 1-N for real)
#'   - `task_begin`: Experiment start time
#'   - `task_end`: Experiment end time (or current time during session)
#'
#' @details
#' This function replicates the structure from the original `extract_behavioral_data()`
#' but with modernized tidyverse conventions. It handles both `steps` and `step`
#' field variants.
#'
#' For behavioral modeling (PR-C), we'll derive:
#' - Hits: signal_flag==1 & response_flag==1 & (response_time - signal_time) < 8000ms
#' - Misses: signal_flag==1 & response_flag==0
#' - False Alarms: signal_flag==0 & response_flag==1
#' - Correct Rejections: signal_flag==0 & response_flag==0
#' - Reaction Times: response_time - signal_time (for hits only)
#'
#' @examples
#' \dontrun{
#' mat_data <- read_mat_data("path/to/file.mat")
#' behavioral_df <- extract_behavioral_trials(mat_data$subjdata, "CSN001")
#' }
#'
#' @keywords internal
extract_behavioral_trials <- function(subjdata, participant_id) {
  
  # Extract basic fields
  n_trials <- as.integer(subjdata$nTrials[1])
  p_signal <- as.numeric(subjdata$pSignal[1])
  exp_begin <- as.numeric(subjdata$expBegin[1])
  exp_end <- as.numeric(subjdata$expEnd[1])
  
  # Extract behavioral matrices
  resps <- subjdata$resps  # n_trials × 2: [response_flag, response_time]
  
  # lr is a SCALAR (0 or 1) - clock position for entire session
  lr_raw <- subjdata$lr
  clock_side <- if (length(lr_raw) == 1) as.numeric(lr_raw[1]) else as.numeric(lr_raw[[1]])
  
  # Image indices
  img_ind <- as.vector(subjdata$img.ind)
  
  # Handle steps vs step field variants
  if ("steps" %in% names(subjdata)) {
    steps <- subjdata$steps
  } else if ("step" %in% names(subjdata)) {
    steps <- subjdata$step
  } else {
    cli::cli_abort(c(
      "Missing signal timing field",
      "x" = "Expected 'steps' or 'step' in subjdata, found: {names(subjdata)}"
    ))
  }
  
  # Create trial-level dataframe (one row per trial)
  behavioral_df <- tibble::tibble(
    trial = 1:n_trials,
    id = participant_id,
    p_signal = p_signal,
    clock_side = clock_side,
    # Signal information
    signal_flag = as.integer(steps[, 1]),  # 0 or 1
    signal_time = steps[, 2],              # Time in ms
    # Response information  
    response_flag = as.integer(resps[, 1]),  # 0 or 1
    response_time = resps[, 2],              # Time in ms (0 if no response)
    # Image information
    image_index = as.integer(img_ind),
    # Session timing
    task_begin = exp_begin,
    task_end = exp_end
  ) |>
    dplyr::mutate(
      # Convert 0 times to NA for cleaner analysis
      signal_time = dplyr::if_else(signal_flag == 0, NA_real_, signal_time),
      response_time = dplyr::if_else(response_flag == 0, NA_real_, response_time),
      # Compute reaction time (response - signal) where both exist
      reaction_time = dplyr::if_else(
        signal_flag == 1 & response_flag == 1,
        response_time - signal_time,
        NA_real_
      )
    )
  
  behavioral_df
}

#' Classify Behavioral Outcomes (Hits, Misses, False Alarms, Correct Rejections)
#'
#' @description
#' Per task.m lines 657-667 and the specification, classify each trial based on
#' signal presence and response timing. A "hit" is a response within 8 seconds
#' of a signal; a "false alarm" is a response when no recent signal occurred.
#'
#' @param behavioral_df Output from `extract_behavioral_trials()`
#' @param response_window_ms Maximum time window for valid responses (default: 8000 ms = 8 sec)
#'
#' @return The behavioral_df with added columns:
#'   - `outcome`: "hit", "miss", "false_alarm", "correct_rejection"
#'   - `is_hit`: Logical
#'   - `is_miss`: Logical
#'   - `is_false_alarm`: Logical
#'   - `is_correct_rejection`: Logical
#'
#' @details
#' Per task.m line 661:
#' ```matlab
#' if any((dbmvst < respst(i)) & (dbmvst > (respst(i)-8)))
#'     ht = ht + 1; % call it a hit
#' else
#'     fa = fa + 1; % false alarm
#' end
#' ```
#'
#' Classification logic:
#' - **Hit**: signal_flag==1 AND response_flag==1 AND reaction_time <= 8000 ms
#' - **Miss**: signal_flag==1 AND (response_flag==0 OR reaction_time > 8000 ms)
#' - **False Alarm**: signal_flag==0 AND response_flag==1
#' - **Correct Rejection**: signal_flag==0 AND response_flag==0
#'
#' @export
classify_behavioral_outcomes <- function(behavioral_df, response_window_ms = 8000) {
  
  behavioral_df |>
    dplyr::mutate(
      # Classify outcomes
      outcome = dplyr::case_when(
        signal_flag == 1 & response_flag == 1 & !is.na(reaction_time) & reaction_time <= response_window_ms ~ "hit",
        signal_flag == 1 & (response_flag == 0 | is.na(reaction_time) | reaction_time > response_window_ms) ~ "miss",
        signal_flag == 0 & response_flag == 1 ~ "false_alarm",
        signal_flag == 0 & response_flag == 0 ~ "correct_rejection",
        TRUE ~ NA_character_
      ),
      # Boolean flags for convenient filtering
      is_hit = outcome == "hit",
      is_miss = outcome == "miss",
      is_false_alarm = outcome == "false_alarm",
      is_correct_rejection = outcome == "correct_rejection"
    )
}

#' Compute Behavioral Summary Statistics
#'
#' @description
#' Computes hits, misses, false alarms, correct rejections, and derived metrics
#' (d-prime, criterion) per the CSN analysis requirements.
#'
#' @param behavioral_df Output from `classify_behavioral_outcomes()`
#'
#' @return A tibble with one row containing summary statistics
#'
#' @export
summarize_behavioral <- function(behavioral_df) {
  
  # Ensure outcomes are classified
  if (!"outcome" %in% names(behavioral_df)) {
    behavioral_df <- classify_behavioral_outcomes(behavioral_df)
  }
  
  # Count outcomes
  n_hits <- sum(behavioral_df$is_hit, na.rm = TRUE)
  n_misses <- sum(behavioral_df$is_miss, na.rm = TRUE)
  n_false_alarms <- sum(behavioral_df$is_false_alarm, na.rm = TRUE)
  n_correct_rejections <- sum(behavioral_df$is_correct_rejection, na.rm = TRUE)
  
  n_signal_trials <- sum(behavioral_df$signal_flag == 1)
  n_no_signal_trials <- sum(behavioral_df$signal_flag == 0)
  
  # Hit rate and false alarm rate
  hit_rate <- n_hits / n_signal_trials
  false_alarm_rate <- n_false_alarms / n_no_signal_trials
  
  # d-prime (signal detection theory)
  # Adjust for 0 or 1 rates (add 0.5, divide by n+1)
  hit_rate_adj <- (n_hits + 0.5) / (n_signal_trials + 1)
  fa_rate_adj <- (n_false_alarms + 0.5) / (n_no_signal_trials + 1)
  
  d_prime <- qnorm(hit_rate_adj) - qnorm(fa_rate_adj)
  criterion <- -0.5 * (qnorm(hit_rate_adj) + qnorm(fa_rate_adj))
  
  # Reaction time statistics (for hits only)
  hit_rts <- behavioral_df |>
    dplyr::filter(is_hit) |>
    dplyr::pull(reaction_time)
  
  # Handle case where there are no hits
  if (length(hit_rts) == 0 || all(is.na(hit_rts))) {
    mean_rt <- NA_real_
    median_rt <- NA_real_
    sd_rt <- NA_real_
    min_rt <- NA_real_
    max_rt <- NA_real_
  } else {
    mean_rt <- mean(hit_rts, na.rm = TRUE)
    median_rt <- median(hit_rts, na.rm = TRUE)
    sd_rt <- sd(hit_rts, na.rm = TRUE)
    min_rt <- min(hit_rts, na.rm = TRUE)
    max_rt <- max(hit_rts, na.rm = TRUE)
  }
  
  tibble::tibble(
    id = unique(behavioral_df$id)[1],
    n_trials = nrow(behavioral_df),
    n_signal_trials = n_signal_trials,
    n_hits = n_hits,
    n_misses = n_misses,
    n_false_alarms = n_false_alarms,
    n_correct_rejections = n_correct_rejections,
    hit_rate = hit_rate,
    false_alarm_rate = false_alarm_rate,
    d_prime = d_prime,
    criterion = criterion,
    mean_rt = mean_rt,
    median_rt = median_rt,
    sd_rt = sd_rt,
    min_rt = min_rt,
    max_rt = max_rt
  )
}

