# Tests for image analysis integration

describe("join_image_content()", {
  
  test_that("join_image_content() merges image attributes", {
    # Create trial data
    trials_df <- tibble::tibble(
      id = rep("P01", 10),
      trial = 1:10,
      image_index = 1:10,
      on_task = sample(c(TRUE, FALSE), 10, replace = TRUE)
    )
    
    # Create image analysis data
    image_data <- tibble::tibble(
      image_index = 1:10,
      arousal = runif(10, 1, 9),
      valence = runif(10, 1, 9),
      category = sample(c("faces", "scenes"), 10, replace = TRUE)
    )
    
    trials_with_images <- join_image_content(trials_df, image_data)
    
    expect_true("arousal" %in% names(trials_with_images))
    expect_true("valence" %in% names(trials_with_images))
    expect_true("category" %in% names(trials_with_images))
    expect_equal(nrow(trials_with_images), nrow(trials_df))
  })
  
  test_that("join_image_content() enforces mismatch tolerance", {
    trials_df <- tibble::tibble(
      id = "P01",
      trial = 1:10,
      image_index = 1:10
    )
    
    # Only 5 images have data (50% mismatch)
    image_data <- tibble::tibble(
      image_index = 1:5,
      arousal = runif(5, 1, 9),
      valence = runif(5, 1, 9)
    )
    
    # Should error with default tolerance (1%)
    expect_error(
      join_image_content(trials_df, image_data, mismatch_tolerance = 0.01),
      "mismatch exceeds tolerance"
    )
    
    # Should succeed with higher tolerance
    expect_warning(
      result <- join_image_content(trials_df, image_data, mismatch_tolerance = 0.6),
      "trials lack image data"
    )
    expect_equal(nrow(result), 10)
  })
  
  test_that("join_image_content() handles image_id vs image_index", {
    trials_df <- tibble::tibble(
      id = "P01",
      trial = 1:5,
      image_index = 1:5
    )
    
    # Image data uses image_id instead
    image_data <- tibble::tibble(
      image_id = 1:5,
      arousal = runif(5, 1, 9)
    )
    
    trials_with_images <- join_image_content(trials_df, image_data)
    
    expect_true("arousal" %in% names(trials_with_images))
  })
  
})


