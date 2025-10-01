# Tests for calibration and validation functions

test_that("parse_validation_msgs extracts validation metrics", {
  mat_file <- get_synthetic_file("synthetic_01.mat")
  
  mat_data <- read_mat_data(mat_file)
  validation_df <- parse_validation_msgs(mat_data$events)
  
  # Should have 2 rows (pre and post)
  expect_equal(nrow(validation_df), 2)
  
  # Should have expected columns
  expect_named(validation_df, c("id", "time", "type", "avg_err_deg", "max_err_deg", 
                                 "offset_x_px", "offset_y_px", "raw_msg"))
  
  # Should have pre and post types
  expect_setequal(validation_df$type, c("pre", "post"))
  
  # All metrics should be numeric and not NA
  expect_type(validation_df$avg_err_deg, "double")
  expect_type(validation_df$max_err_deg, "double")
  expect_type(validation_df$offset_x_px, "double")
  expect_type(validation_df$offset_y_px, "double")
  
  expect_false(any(is.na(validation_df$avg_err_deg)))
  expect_false(any(is.na(validation_df$max_err_deg)))
  expect_false(any(is.na(validation_df$offset_x_px)))
  expect_false(any(is.na(validation_df$offset_y_px)))
  
  # Validation errors should be positive
  expect_true(all(validation_df$avg_err_deg > 0))
  expect_true(all(validation_df$max_err_deg > 0))
})

test_that("parse_validation_msgs handles missing calibration events gracefully", {
  # Create events without calibration
  events_no_cal <- tibble::tibble(
    id = "TEST01",
    type = c("signal", "response", "image_onset"),
    t = c(100, 200, 300),
    msg = c("signal_on", "response", "image_onset image_001.jpg")
  )
  
  expect_warning(
    result <- parse_validation_msgs(events_no_cal),
    "No calibration events found"
  )
  
  expect_equal(nrow(result), 0)
  expect_named(result, c("id", "time", "type", "avg_err_deg", "max_err_deg",
                         "offset_x_px", "offset_y_px", "raw_msg"))
})

test_that("summarize_validation_relationships computes statistics correctly", {
  # Create simple validation data
  validation_df <- tibble::tibble(
    id = rep(c("P01", "P02"), each = 2),
    time = c(0, 60000, 0, 60000),
    type = rep(c("pre", "post"), 2),
    avg_err_deg = c(0.5, 0.6, 0.4, 0.7),
    max_err_deg = c(1.0, 1.2, 0.9, 1.3),
    offset_x_px = c(10, 12, 8, 15),
    offset_y_px = c(20, 18, 22, 19),
    raw_msg = paste("!CAL VALIDATION", rep(c("pre", "post"), 2))
  )
  
  result <- summarize_validation_relationships(validation_df)
  
  # Should return a list with expected components
  expect_type(result, "list")
  expect_named(result, c("subject_summary", "global_summary", "correlation", "paired_test"))
  
  # Subject summary should have one row per participant
  expect_equal(nrow(result$subject_summary), 2)
  
  # Global summary should have metrics for all fields
  expect_s3_class(result$global_summary, "tbl_df")
  expect_true("metric" %in% names(result$global_summary))
  expect_true("pre_mean" %in% names(result$global_summary))
  expect_true("post_mean" %in% names(result$global_summary))
  expect_true("mean_diff" %in% names(result$global_summary))
  
  # Correlation and paired test may be NULL with small n
  # (need n > 2 for valid statistics)
  expect_true(is.null(result$correlation) || is.list(result$correlation))
  expect_true(is.null(result$paired_test) || is.list(result$paired_test))
})

test_that("summarize_validation_relationships handles single participant", {
  # Single participant
  validation_df <- tibble::tibble(
    id = c("P01", "P01"),
    time = c(0, 60000),
    type = c("pre", "post"),
    avg_err_deg = c(0.5, 0.6),
    max_err_deg = c(1.0, 1.2),
    offset_x_px = c(10, 12),
    offset_y_px = c(20, 18),
    raw_msg = c("!CAL VALIDATION pre", "!CAL VALIDATION post")
  )
  
  result <- summarize_validation_relationships(validation_df)
  
  # Should still compute global summary
  expect_s3_class(result$global_summary, "tbl_df")
  expect_equal(nrow(result$subject_summary), 1)
  
  # Correlation/t-test will be NULL with n < 3
  expect_null(result$correlation)
  expect_null(result$paired_test)
})

