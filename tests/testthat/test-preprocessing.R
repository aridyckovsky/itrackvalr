# Tests for preprocessing functions

describe("compute_distance()", {
  
  test_that("compute_distance() adds distance column", {
    # Create simple test data (without adjusted coords, so warning expected)
    samples_with_hand <- tibble::tibble(
      id = "TEST01",
      t = 1:10,
      x_px = rep(640, 10),
      y_px = rep(512, 10),
      tip_x_px = rep(700, 10),
      tip_y_px = rep(512, 10),
      blink = rep(FALSE, 10)
    )
    
    # Expect warning since no adjusted coordinates
    expect_warning(
      samples_with_dist <- compute_distance(samples_with_hand),
      "Adjusted coordinates requested but not found"
    )
    
    expect_true("dist_to_tip_px" %in% names(samples_with_dist))
    expect_type(samples_with_dist$dist_to_tip_px, "double")
    
    # Distance should be 60 pixels (700 - 640)
    expect_equal(samples_with_dist$dist_to_tip_px[1], 60, tolerance = 0.1)
  })
  
  test_that("compute_distance() uses adjusted coordinates when available", {
    samples_with_hand <- tibble::tibble(
      id = "TEST01",
      t = 1:5,
      x_px = rep(640, 5),
      y_px = rep(512, 5),
      x_px_adj = rep(650, 5),  # Offset by 10px
      y_px_adj = rep(512, 5),
      tip_x_px = rep(700, 5),
      tip_y_px = rep(512, 5),
      blink = rep(FALSE, 5)
    )
    
    # With use_adjusted = TRUE (default)
    samples_adj <- compute_distance(samples_with_hand, use_adjusted = TRUE)
    # Distance from 650 to 700 = 50px
    expect_equal(samples_adj$dist_to_tip_px[1], 50, tolerance = 0.1)
    
    # With use_adjusted = FALSE
    samples_raw <- compute_distance(samples_with_hand, use_adjusted = FALSE)
    # Distance from 640 to 700 = 60px
    expect_equal(samples_raw$dist_to_tip_px[1], 60, tolerance = 0.1)
  })
  
})

describe("binarize_on_task()", {
  
  test_that("binarize_on_task() classifies based on distance", {
    samples_with_dist <- tibble::tibble(
      id = c("P01", "P01", "P01"),
      dist_to_tip_px = c(10, 30, 50),  # Within, within, outside
      blink = c(FALSE, FALSE, FALSE)
    )
    
    zone_radii <- tibble::tibble(
      id = "P01",
      r_px = 25  # 25px threshold
    )
    
    samples_binarized <- binarize_on_task(samples_with_dist, zone_radii)
    
    expect_true("on_task" %in% names(samples_binarized))
    expect_equal(samples_binarized$on_task, c(TRUE, FALSE, FALSE))
  })
  
  test_that("binarize_on_task() sets blinks to NA", {
    samples_with_dist <- tibble::tibble(
      id = c("P01", "P01"),
      dist_to_tip_px = c(10, 10),
      blink = c(FALSE, TRUE)  # Second is blink
    )
    
    zone_radii <- tibble::tibble(
      id = "P01",
      r_px = 25
    )
    
    samples_binarized <- binarize_on_task(samples_with_dist, zone_radii)
    
    expect_equal(samples_binarized$on_task[1], TRUE)
    expect_true(is.na(samples_binarized$on_task[2]))  # Blink → NA
  })
  
  test_that("binarize_on_task() handles missing zone radius", {
    samples_with_dist <- tibble::tibble(
      id = "P01",
      dist_to_tip_px = 10,
      blink = FALSE
    )
    
    zone_radii <- tibble::tibble(
      id = "P01",
      r_px = NA_real_  # Missing radius
    )
    
    samples_binarized <- binarize_on_task(samples_with_dist, zone_radii)
    
    # Should be NA when radius is missing
    expect_true(is.na(samples_binarized$on_task[1]))
  })
  
})

describe("segment_trials()", {
  
  test_that("segment_trials() creates trial-level data", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    
    # Classify behavioral outcomes first
    behavioral_classified <- classify_behavioral_outcomes(mat_data$behavioral)
    
    # Create minimal binarized data
    samples_binarized <- mat_data$samples |>
      dplyr::mutate(on_task = sample(c(TRUE, FALSE), dplyr::n(), replace = TRUE))
    
    trial_segments <- segment_trials(
      samples_binarized[1:5000, ],  # Subset for speed
      mat_data$events,
      behavioral_classified
    )
    
    expect_s3_class(trial_segments, "tbl_df")
    expect_true("trial" %in% names(trial_segments))
    expect_true("t_trial_ms" %in% names(trial_segments))
    expect_true("t_absolute" %in% names(trial_segments))
    expect_true("image_index" %in% names(trial_segments))
  })
  
  test_that("segment_trials() normalizes time to trial start", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    
    behavioral_classified <- classify_behavioral_outcomes(mat_data$behavioral)
    
    samples_binarized <- mat_data$samples |>
      dplyr::mutate(on_task = TRUE)
    
    trial_segments <- segment_trials(
      samples_binarized[1:5000, ],
      mat_data$events,
      behavioral_classified[1:5, ]  # Just first 5 trials
    )
    
    # Each trial should start at t_trial_ms = 0 or near 0
    trial_starts <- trial_segments |>
      dplyr::group_by(trial) |>
      dplyr::summarise(min_t = min(t_trial_ms))
    
    expect_true(all(trial_starts$min_t <= 10))  # Within 10ms of start
  })
  
})

