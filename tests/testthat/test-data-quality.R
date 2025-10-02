# Data Quality and Integration Tests
# These tests verify the pipeline produces sensible output, not just code execution

describe("Pipeline output data quality", {
  
  test_that("Trial segmentation produces correct sample counts", {
    # Run mini pipeline
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    behavioral_classified <- classify_behavioral_outcomes(mat_data$behavioral)
    
    # Create mock binarized data
    samples_bin <- mat_data$samples |> dplyr::mutate(on_task = FALSE)
    
    trials <- segment_trials(samples_bin, mat_data$events, behavioral_classified)
    
    # Should be ~500 samples per trial (500 Hz × 1000 ms)
    samples_per_trial <- trials |>
      dplyr::group_by(trial) |>
      dplyr::summarise(n = dplyr::n())
    
    expect_true(all(samples_per_trial$n >= 490 & samples_per_trial$n <= 510))
    expect_equal(mean(samples_per_trial$n), 500, tolerance = 10)
  })
  
  test_that("Calibration offsets are applied correctly", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    validation_df <- parse_validation_msgs(mat_data$events)
    
    samples_adj <- apply_calibration_offsets(
      mat_data$samples[1:100, ],
      validation_df,
      method = "pre"
    )
    
    # Verify offsets were actually applied
    actual_offset_x <- samples_adj$x_px[1] - samples_adj$x_px_adj[1]
    expected_offset_x <- validation_df$offset_x_px[validation_df$type == "pre"]
    
    expect_equal(actual_offset_x, expected_offset_x, tolerance = 0.01)
  })
  
  test_that("Zone radius calculation is mathematically correct", {
    # Create known validation data
    validation_df <- tibble::tibble(
      id = c("TEST", "TEST"),
      time = c(0, 60000),
      type = c("pre", "post"),
      avg_err_deg = c(0.5, 0.6),  # Average = 0.55°
      max_err_deg = c(1.0, 1.2),
      offset_x_px = c(10, 12),
      offset_y_px = c(20, 18),
      raw_msg = c("pre", "post")
    )
    
    # Manual calculation
    cfg <- get_test_config()
    zone_df <- compute_zone_radius(validation_df, strategy = "average", cfg = cfg)
    deg_avg <- 0.55
    expected_px <- 2 * cfg$screen$viewing_distance_mm * 
                   tan(deg_avg * pi / 360) * 
                   (cfg$screen$width_px / cfg$screen$width_mm)
    
    expect_equal(zone_df$r_px, expected_px, tolerance = 0.1)
  })
  
  test_that("On-task classification logic is sound", {
    samples_with_dist <- tibble::tibble(
      id = c("TEST", "TEST", "TEST", "TEST"),
      dist_to_tip_px = c(10, 23.5, 23.7, 50),  # Within, edge, edge, outside
      blink = c(FALSE, FALSE, FALSE, FALSE)
    )
    
    zone_radii <- tibble::tibble(id = "TEST", r_px = 23.6)
    
    samples_bin <- binarize_on_task(samples_with_dist, zone_radii)
    
    # Check classification
    expect_true(samples_bin$on_task[1])   # 10 < 23.6 → TRUE
    expect_true(samples_bin$on_task[2])   # 23.5 < 23.6 → TRUE
    expect_false(samples_bin$on_task[3])  # 23.7 > 23.6 → FALSE
    expect_false(samples_bin$on_task[4])  # 50 > 23.6 → FALSE
  })
  
  test_that("Distance calculation is geometrically correct", {
    # Known positions
    samples <- tibble::tibble(
      id = "TEST",
      x_px = c(0, 3, 0),
      y_px = c(0, 0, 4),
      tip_x_px = c(0, 0, 0),
      tip_y_px = c(0, 0, 0),
      blink = FALSE
    )
    
    samples_dist <- compute_distance(samples, use_adjusted = FALSE)
    
    # Check Euclidean distances
    expect_equal(samples_dist$dist_to_tip_px[1], 0)  # Same point
    expect_equal(samples_dist$dist_to_tip_px[2], 3)  # Horizontal
    expect_equal(samples_dist$dist_to_tip_px[3], 4)  # Vertical
  })
  
  test_that("Hand positions stay on screen bounds", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    cfg <- get_test_config()
    
    hand_positions <- derive_hand_dynamics(
      mat_data$metadata,
      mat_data$events,
      cfg
    )
    
    # Hand should stay within reasonable screen bounds
    # (May slightly exceed due to hand length extending from center)
    margin <- 200  # pixels
    expect_true(all(hand_positions$tip_x_px > -margin))
    expect_true(all(hand_positions$tip_x_px < cfg$screen$width_px + margin))
    expect_true(all(hand_positions$tip_y_px > -margin))
    expect_true(all(hand_positions$tip_y_px < cfg$screen$height_px + margin))
  })
  
  test_that("Resampling produces uniform grid", {
    mat_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
    
    samples_resampled <- resample_samples(
      mat_data$samples[1:1000, ],
      hz_standard = 500
    )
    
    # Check time intervals
    time_diffs <- diff(samples_resampled$t)
    expected_interval <- 2  # ms (500 Hz)
    
    # Most intervals should be 2ms (allow some variation for rounding)
    expect_true(mean(abs(time_diffs - expected_interval) < 0.5) > 0.95)
  })
  
})

describe("End-to-end pipeline validation", {
  
  test_that("Complete preprocessing chain produces valid output", {
    skip("Run manually for full validation")
    
    # This would run the complete pipeline and verify:
    # - All outputs have expected dimensions
    # - No NA values where unexpected
    # - Distributions are reasonable
    # - File sizes match expectations
  })
  
})


