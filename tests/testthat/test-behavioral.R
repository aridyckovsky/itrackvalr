# Tests for behavioral data extraction and analysis

test_that("extract_behavioral_trials creates correct structure", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  mat_data <- read_mat_data(mat_file)
  
  behavioral <- mat_data$behavioral
  
  # Should be a tibble
  expect_s3_class(behavioral, "tbl_df")
  
  # Should have 60 rows (60 trials)
  expect_equal(nrow(behavioral), 60)
  
  # Should have required columns
  required_cols <- c("trial", "id", "p_signal", "clock_side", 
                     "signal_flag", "signal_time", "response_flag", "response_time",
                     "image_index", "task_begin", "task_end", "reaction_time")
  for (col in required_cols) {
    expect_true(col %in% names(behavioral), 
                info = paste("Missing required column:", col))
  }
  
  # Trial numbers should be 1 to n_trials
  expect_equal(behavioral$trial, 1:60)
  
  # clock_side should be constant (scalar for session)
  expect_equal(length(unique(behavioral$clock_side)), 1)
  expect_true(unique(behavioral$clock_side) %in% c(0, 1))
  
  # p_signal should be 0.01 (1%)
  expect_equal(unique(behavioral$p_signal), 0.01)
  
  # signal_flag should be 0 or 1
  expect_true(all(behavioral$signal_flag %in% c(0, 1)))
  
  # response_flag should be 0 or 1
  expect_true(all(behavioral$response_flag %in% c(0, 1)))
  
  # signal_time should be NA when signal_flag == 0
  no_signal_trials <- behavioral |> dplyr::filter(signal_flag == 0)
  expect_true(all(is.na(no_signal_trials$signal_time)))
  
  # signal_time should be numeric when signal_flag == 1
  signal_trials <- behavioral |> dplyr::filter(signal_flag == 1)
  if (nrow(signal_trials) > 0) {
    expect_true(all(!is.na(signal_trials$signal_time)))
    expect_type(signal_trials$signal_time, "double")
  }
})

test_that("classify_behavioral_outcomes correctly classifies trials", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  mat_data <- read_mat_data(mat_file)
  
  behavioral <- mat_data$behavioral
  classified <- classify_behavioral_outcomes(behavioral)
  
  # Should have outcome columns
  expect_true("outcome" %in% names(classified))
  expect_true("is_hit" %in% names(classified))
  expect_true("is_miss" %in% names(classified))
  expect_true("is_false_alarm" %in% names(classified))
  expect_true("is_correct_rejection" %in% names(classified))
  
  # Outcomes should be classified
  expect_true(all(!is.na(classified$outcome)))
  expect_true(all(classified$outcome %in% c("hit", "miss", "false_alarm", "correct_rejection")))
  
  # Boolean flags should match outcome
  expect_equal(classified$is_hit, classified$outcome == "hit")
  expect_equal(classified$is_miss, classified$outcome == "miss")
  expect_equal(classified$is_false_alarm, classified$outcome == "false_alarm")
  expect_equal(classified$is_correct_rejection, classified$outcome == "correct_rejection")
  
  # Logic checks
  # Hits: signal AND response within 8 seconds
  hits <- classified |> dplyr::filter(is_hit)
  if (nrow(hits) > 0) {
    expect_true(all(hits$signal_flag == 1))
    expect_true(all(hits$response_flag == 1))
    expect_true(all(hits$reaction_time <= 8000, na.rm = TRUE))
  }
  
  # Misses: signal but no (timely) response
  misses <- classified |> dplyr::filter(is_miss)
  if (nrow(misses) > 0) {
    expect_true(all(misses$signal_flag == 1))
  }
  
  # False alarms: no signal but response
  fas <- classified |> dplyr::filter(is_false_alarm)
  if (nrow(fas) > 0) {
    expect_true(all(fas$signal_flag == 0))
    expect_true(all(fas$response_flag == 1))
  }
  
  # Correct rejections: no signal, no response
  crs <- classified |> dplyr::filter(is_correct_rejection)
  if (nrow(crs) > 0) {
    expect_true(all(crs$signal_flag == 0))
    expect_true(all(crs$response_flag == 0))
  }
})

test_that("classify_behavioral_outcomes uses 8-second response window", {
  # Create test data with specific reaction times
  test_behavioral <- tibble::tibble(
    trial = 1:4,
    id = "TEST",
    p_signal = 0.01,
    clock_side = 0,
    signal_flag = c(1, 1, 1, 0),
    signal_time = c(1000, 2000, 3000, NA),
    response_flag = c(1, 1, 1, 1),
    response_time = c(1500, 9500, 4000, 1000),  # RT: 500ms, 7500ms, 1000ms, NA
    image_index = c(1, 2, 3, 4),
    task_begin = 0,
    task_end = 10000
  ) |>
    dplyr::mutate(
      signal_time = dplyr::if_else(signal_flag == 0, NA_real_, signal_time),
      response_time = dplyr::if_else(response_flag == 0, NA_real_, response_time),
      reaction_time = dplyr::if_else(
        signal_flag == 1 & response_flag == 1,
        response_time - signal_time,
        NA_real_
      )
    )
  
  classified <- classify_behavioral_outcomes(test_behavioral, response_window_ms = 8000)
  
  # Trial 1: RT = 500ms (< 8000) → HIT
  expect_equal(classified$outcome[1], "hit")
  
  # Trial 2: RT = 7500ms (< 8000) → HIT
  expect_equal(classified$outcome[2], "hit")
  
  # Trial 3: RT = 1000ms (< 8000) → HIT
  expect_equal(classified$outcome[3], "hit")
  
  # Trial 4: No signal, but response → FALSE ALARM
  expect_equal(classified$outcome[4], "false_alarm")
})

test_that("summarize_behavioral computes correct statistics", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  mat_data <- read_mat_data(mat_file)
  
  classified <- classify_behavioral_outcomes(mat_data$behavioral)
  summary <- summarize_behavioral(classified)
  
  # Should be a single-row tibble
  expect_s3_class(summary, "tbl_df")
  expect_equal(nrow(summary), 1)
  
  # Should have all required columns
  required_cols <- c("id", "n_trials", "n_signal_trials", 
                     "n_hits", "n_misses", "n_false_alarms", "n_correct_rejections",
                     "hit_rate", "false_alarm_rate", "d_prime", "criterion",
                     "mean_rt", "median_rt", "sd_rt", "min_rt", "max_rt")
  expect_true(all(required_cols %in% names(summary)))
  
  # Counts should sum to n_trials
  total_outcomes <- summary$n_hits + summary$n_misses + 
                    summary$n_false_alarms + summary$n_correct_rejections
  expect_equal(total_outcomes, summary$n_trials)
  
  # Hits + misses should equal signal trials
  expect_equal(summary$n_hits + summary$n_misses, summary$n_signal_trials)
  
  # FAs + CRs should equal no-signal trials
  expect_equal(summary$n_false_alarms + summary$n_correct_rejections, 
               summary$n_trials - summary$n_signal_trials)
  
  # Rates should be proportions [0, 1]
  expect_gte(summary$hit_rate, 0)
  expect_lte(summary$hit_rate, 1)
  expect_gte(summary$false_alarm_rate, 0)
  expect_lte(summary$false_alarm_rate, 1)
  
  # d-prime should be finite (with adjustment for 0/1 rates)
  expect_true(is.finite(summary$d_prime))
})

test_that("summarize_behavioral handles zero hits gracefully", {
  # Create data with no hits (all misses on signal trials)
  test_behavioral <- tibble::tibble(
    trial = 1:10,
    id = "TEST",
    p_signal = 0.01,
    clock_side = 0,
    signal_flag = c(1, 1, rep(0, 8)),
    signal_time = c(1000, 2000, rep(NA, 8)),
    response_flag = rep(0, 10),
    response_time = rep(NA, 10),
    image_index = 1:10,
    task_begin = 0,
    task_end = 10000
  ) |>
    dplyr::mutate(
      reaction_time = NA_real_
    )
  
  classified <- classify_behavioral_outcomes(test_behavioral)
  summary <- summarize_behavioral(classified)
  
  # Should have 0 hits, 2 misses
  expect_equal(summary$n_hits, 0)
  expect_equal(summary$n_misses, 2)
  
  # RT stats should be NA (no hits)
  expect_true(is.na(summary$mean_rt))
  expect_true(is.na(summary$median_rt))
  expect_true(is.na(summary$min_rt))
  expect_true(is.na(summary$max_rt))
  
  # d-prime should still be computable (with adjustment)
  expect_true(is.finite(summary$d_prime))
})

