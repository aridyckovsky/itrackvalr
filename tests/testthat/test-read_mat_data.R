# Tests for read_mat_data() and related functions

test_that("read_mat_data reads synthetic .mat files correctly", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  
  result <- read_mat_data(mat_file)
  
  # Should return a list with four components
  expect_type(result, "list")
  expect_named(result, c("samples", "events", "metadata", "behavioral"))
  
  # Samples should be a tibble with expected columns
  expect_s3_class(result$samples, "tbl_df")
  expect_named(result$samples, c("id", "t", "x_px", "y_px", "pupil", "eye", "blink", "inside_screen"))
  
  # Should have 30000 samples (60 seconds × 500 Hz)
  expect_equal(nrow(result$samples), 30000)
  
  # All eye values should be "RIGHT" (monocular)
  expect_true(all(result$samples$eye == "RIGHT"))
  
  # Events should be a tibble
  expect_s3_class(result$events, "tbl_df")
  expect_true("type" %in% names(result$events))
  expect_true("t" %in% names(result$events))
  expect_true("msg" %in% names(result$events))
  
  # Should have multiple event types
  event_types <- unique(result$events$type)
  expect_true("calibration" %in% event_types)
  expect_true("signal" %in% event_types)
  expect_true("response" %in% event_types)
  expect_true("image_onset" %in% event_types)
  expect_true("image_offset" %in% event_types)
  
  # Metadata should contain expected fields
  expect_s3_class(result$metadata, "tbl_df")
  expect_equal(result$metadata$id, "SYN01")
  expect_equal(result$metadata$n_trials, 60)
  expect_equal(result$metadata$sampling_rate_hz, 500)
  expect_equal(result$metadata$duration_ms, 60000)
})

test_that("read_mat_data handles steps/step field variants", {
  # This test assumes both variants exist in our test fixtures
  # For now, we only have 'steps' in synthetic data
  mat_file <- get_synthetic_file("synthetic_01.mat")
  
  # Should not error with 'steps' field
  expect_no_error(read_mat_data(mat_file))
  
  # If we had a fixture with 'step' instead, it should also work
  # (This will be tested when real data is available)
})

test_that("read_mat_data extracts behavioral events correctly", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  
  result <- read_mat_data(mat_file)
  
  # Should have signal events
  signal_events <- result$events |> dplyr::filter(type == "signal")
  expect_gt(nrow(signal_events), 0)
  expect_true(all(!is.na(signal_events$t)))
  # signal_flag column exists only for signal events (NA for others after bind_rows)
  expect_true(all(signal_events$signal_flag == 1, na.rm = TRUE))
  
  # Should have response events
  response_events <- result$events |> dplyr::filter(type == "response")
  expect_gt(nrow(response_events), 0)
  expect_true(all(!is.na(response_events$t)))
  # response_flag column exists only for response events (NA for others after bind_rows)
  expect_true(all(response_events$response_flag == 1, na.rm = TRUE))
  
  # Response times should be after signal times (when they occur on same trial)
  # This is a basic sanity check
  expect_true(all(response_events$t >= 0))
})

test_that("read_mat_data parses calibration messages", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  
  result <- read_mat_data(mat_file)
  
  # Should have calibration events
  cal_events <- result$events |> dplyr::filter(type == "calibration")
  expect_equal(nrow(cal_events), 2)  # Pre and post
  
  # Should have parsed validation metrics
  expect_false(all(is.na(cal_events$avg_err_deg)))
  expect_false(all(is.na(cal_events$max_err_deg)))
  expect_false(all(is.na(cal_events$offset_x_px)))
  expect_false(all(is.na(cal_events$offset_y_px)))
  
  # Should have pre and post validation types
  expect_true("pre" %in% cal_events$validation_type)
  expect_true("post" %in% cal_events$validation_type)
})

test_that("read_mat_data extracts gaze data correctly", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  
  result <- read_mat_data(mat_file)
  
  # Gaze positions should be numeric
  expect_type(result$samples$x_px, "double")
  expect_type(result$samples$y_px, "double")
  expect_type(result$samples$pupil, "double")
  
  # Should have no NA values in time
  expect_false(any(is.na(result$samples$t)))
  
  # Time should be monotonically increasing
  expect_true(all(diff(result$samples$t) >= 0))
  
  # Timestamps should span the full duration
  expect_equal(min(result$samples$t), 0)
  expect_lte(max(result$samples$t), result$metadata$duration_ms)
})

