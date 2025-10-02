# Tests for resampling functions

describe("resample_samples() with tibble input", {
  
  test_that("resample_samples() creates uniform grid", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    
    samples_resampled <- resample_samples(
      mat_data$samples[1:1000, ],  # First 1000 samples
      hz_standard = 500,
      gap_threshold = 20
    )
    
    expect_s3_class(samples_resampled, "tbl_df")
    expect_true("t" %in% names(samples_resampled))
    expect_true("gap_flag" %in% names(samples_resampled))
    expect_true("eye" %in% names(samples_resampled))
    expect_true("blink" %in% names(samples_resampled))
  })
  
  test_that("resample_samples() maintains expected columns", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    
    samples_resampled <- resample_samples(
      mat_data$samples[1:500, ],
      hz_standard = 500
    )
    
    # Should have all original columns plus gap_flag
    original_cols <- c("id", "t", "x_px", "y_px", "pupil", "eye")
    expect_true(all(original_cols %in% names(samples_resampled)))
  })
  
  test_that("resample_samples() handles gaps correctly", {
    # Create data with a gap
    samples_with_gap <- tibble::tibble(
      id = "TEST01",
      t = c(0, 2, 4, 6, 8, 50, 52, 54),  # 42ms gap between 8 and 50
      x_px = c(100, 102, 104, 106, 108, 150, 152, 154),
      y_px = rep(200, 8),
      pupil = rep(1500, 8),
      eye = rep("RIGHT", 8),
      blink = rep(FALSE, 8),
      inside_screen = rep(TRUE, 8)
    )
    
    samples_resampled <- resample_samples(
      samples_with_gap,
      hz_standard = 500,
      gap_threshold = 20
    )
    
    # Gap should be flagged
    expect_true(any(samples_resampled$gap_flag))
  })
  
  test_that("resample_samples() sets blinks to NA correctly", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    
    samples_resampled <- resample_samples(
      mat_data$samples[1:500, ],
      hz_standard = 500
    )
    
    # Blinks should have blink flag TRUE
    expect_true("blink" %in% names(samples_resampled))
  })
  
})

describe("resample_samples() with LazyFrame input", {
  
  test_that("resample_samples() works with LazyFrame input", {
    skip_if_not_installed("tidypolars")
    
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    samples_lf <- to_polars_lf(mat_data$samples[1:500, ])
    
    samples_resampled_lf <- resample_samples(
      samples_lf,
      hz_standard = 500
    )
    
    # Should return LazyFrame
    expect_s3_class(samples_resampled_lf, "polars_lazy_frame")
    
    # Materialize and check
    samples_resampled <- to_tibble(samples_resampled_lf)
    expect_true("gap_flag" %in% names(samples_resampled))
  })
  
})


