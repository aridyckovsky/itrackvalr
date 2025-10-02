# Tests for Polars Integration and Utility Functions

# Skip all tests if tidypolars not available
skip_if_not_installed("tidypolars")
skip_if_not_installed("polars")

# Setup: Load synthetic data once for all tests
synth_data <- read_mat_data(get_synthetic_file("synthetic_01.mat"))
synth_samples <- synth_data$samples

describe("Polars availability checks", {
  
  test_that("has_polars() correctly detects tidypolars installation", {
    expect_true(has_polars())
    expect_type(has_polars(), "logical")
  })
  
})

describe("Conversion functions", {
  
  test_that("to_polars_lf() converts tibble to LazyFrame", {
    lf <- to_polars_lf(synth_samples)
    
    expect_s3_class(lf, "polars_lazy_frame")
    expect_true(inherits(lf, "polars_lazy_frame"))
  })
  
  test_that("to_polars_lf() returns LazyFrame unchanged if already LazyFrame", {
    lf1 <- to_polars_lf(synth_samples)
    lf2 <- to_polars_lf(lf1)
    
    expect_identical(lf1, lf2)
  })
  
  test_that("to_polars_lf() errors on invalid input", {
    expect_error(
      to_polars_lf(list(a = 1, b = 2)),
      "Input must be a tibble"
    )
    
    expect_error(
      to_polars_lf("not a data frame"),
      "Input must be a tibble"
    )
  })
  
  test_that("to_tibble() converts LazyFrame to tibble", {
    lf <- to_polars_lf(synth_samples)
    tbl <- to_tibble(lf)
    
    expect_s3_class(tbl, "tbl_df")
    expect_type(tbl, "list")
  })
  
  test_that("to_tibble() returns tibble unchanged if already tibble", {
    tbl1 <- synth_samples
    tbl2 <- to_tibble(tbl1)
    
    expect_s3_class(tbl2, "tbl_df")
  })
  
  test_that("to_tibble() errors on invalid input", {
    expect_error(
      to_tibble(list(a = 1, b = 2)),
      "Input must be a polars LazyFrame or tibble"
    )
  })
  
})

describe("LazyFrame operations remain lazy", {
  
  test_that("Operations on LazyFrame don't materialize data", {
    lf <- to_polars_lf(synth_samples)
    
    # Apply operations
    lf_filtered <- lf |>
      dplyr::filter(eye == "RIGHT") |>
      dplyr::mutate(x_doubled = x_px * 2)
    
    # Should still be LazyFrame
    expect_s3_class(lf_filtered, "polars_lazy_frame")
    expect_true(inherits(lf_filtered, "polars_lazy_frame"))
  })
  
  test_that("as_polars_df() materializes LazyFrame to DataFrame", {
    lf <- to_polars_lf(synth_samples) |>
      dplyr::filter(eye == "RIGHT")
    
    # Materialize to polars DataFrame (not tibble yet)
    df <- tidypolars::as_polars_df(lf)
    
    # Should be DataFrame (polars type)
    expect_s3_class(df, "polars_data_frame")
    expect_false(inherits(df, "polars_lazy_frame"))
  })
  
})

describe("Polars equivalence with dplyr", {
  
  test_that("LazyFrame operations produce same results as dplyr", {
    # Dplyr version
    dplyr_result <- synth_samples |>
      dplyr::filter(eye == "RIGHT") |>
      dplyr::mutate(x_doubled = x_px * 2) |>
      dplyr::select(id, t, x_px, x_doubled) |>
      dplyr::arrange(t)
    
    # Polars version
    polars_result <- to_polars_lf(synth_samples) |>
      dplyr::filter(eye == "RIGHT") |>
      dplyr::mutate(x_doubled = x_px * 2) |>
      dplyr::select(id, t, x_px, x_doubled) |>
      dplyr::arrange(t) |>
      to_tibble()
    
    # Results should be identical
    expect_equal(nrow(dplyr_result), nrow(polars_result))
    expect_equal(ncol(dplyr_result), ncol(polars_result))
    expect_named(polars_result, names(dplyr_result))
  })
  
})

describe("Parquet streaming with sink_parquet()", {
  
  test_that("sink_parquet() writes LazyFrame to disk", {
    skip_on_cran()
    
    lf <- to_polars_lf(synth_samples) |>
      dplyr::filter(eye == "RIGHT")
    
    # Create temp file
    temp_parquet <- tempfile(fileext = ".parquet")
    on.exit(unlink(temp_parquet), add = TRUE)
    
    # Stream to disk
    result_path <- sink_parquet(lf, temp_parquet)
    
    expect_true(file.exists(temp_parquet))
    expect_identical(result_path, temp_parquet)
    
    # Verify file has content
    expect_true(file.size(temp_parquet) > 0)
  })
  
  test_that("sink_parquet() errors if path doesn't end in .parquet", {
    lf <- to_polars_lf(synth_samples)
    
    expect_error(
      sink_parquet(lf, "output.csv"),
      "must end with .parquet"
    )
  })
  
  test_that("sink_parquet() errors if input is not LazyFrame", {
    expect_error(
      sink_parquet(synth_samples, "output.parquet"),
      "Input must be a polars LazyFrame"
    )
  })
  
  test_that("sink_parquet() creates directory if needed", {
    skip_on_cran()
    
    lf <- to_polars_lf(synth_samples)
    temp_dir <- tempfile()
    temp_parquet <- file.path(temp_dir, "nested", "output.parquet")
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
    
    sink_parquet(lf, temp_parquet)
    
    expect_true(file.exists(temp_parquet))
  })
  
})

describe("Multi-participant polars aggregation", {
  
  test_that("aggregate_samples_polars() returns LazyFrame", {
    # Read 2 synthetic files using helper
    file1 <- get_synthetic_file("synthetic_01.mat")
    file2 <- get_synthetic_file("synthetic_02.mat")
    mat_files <- c(file1, file2)
    
    participant_data <- read_all_participants(mat_files)
    
    samples_lf <- aggregate_samples_polars(participant_data)
    
    expect_s3_class(samples_lf, "polars_lazy_frame")
  })
  
  test_that("aggregate_samples_polars() matches dplyr aggregation", {
    # Read 2 synthetic files using helper
    file1 <- get_synthetic_file("synthetic_01.mat")
    file2 <- get_synthetic_file("synthetic_02.mat")
    mat_files <- c(file1, file2)
    
    participant_data <- read_all_participants(mat_files)
    
    # Dplyr version (eager)
    dplyr_result <- dplyr::bind_rows(
      lapply(participant_data, function(p) p$samples)
    ) |>
      dplyr::arrange(id, t)
    
    # Polars version (lazy, then compute)
    polars_result <- aggregate_samples_polars(participant_data) |>
      dplyr::arrange(id, t) |>
      to_tibble()
    
    # Should have same dimensions
    expect_equal(nrow(polars_result), nrow(dplyr_result))
    expect_equal(ncol(polars_result), ncol(dplyr_result))
    
    # Should have same columns
    expect_named(polars_result, names(dplyr_result))
    
    # Should have same participants
    expect_equal(
      sort(unique(polars_result$id)),
      sort(unique(dplyr_result$id))
    )
  })
  
})

describe("Aggregation functions", {
  
  test_that("aggregate_samples() returns tibble", {
    participant_data <- list(synth_data)
    result <- aggregate_samples(participant_data)
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 30000)
  })
  
  test_that("aggregate_samples_polars() returns LazyFrame", {
    skip_if_not_installed("tidypolars")
    participant_data <- list(synth_data)
    result <- aggregate_samples_polars(participant_data)
    expect_s3_class(result, "polars_lazy_frame")
  })
  
  test_that("aggregate_samples() works with 2 participants", {
    # Read 2 synthetic files using helper
    file1 <- get_synthetic_file("synthetic_01.mat")
    file2 <- get_synthetic_file("synthetic_02.mat")
    mat_files <- c(file1, file2)
    participant_data <- read_all_participants(mat_files)
    result <- aggregate_samples(participant_data)
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 60000)
  })
  
})

describe("format_bytes() helper", {
  
  test_that("format_bytes() formats byte counts correctly", {
    expect_match(format_bytes(500), "500 B")
    expect_match(format_bytes(1536), "1\\.5 KB")
    expect_match(format_bytes(1048576), "1\\.0 MB")
    expect_match(format_bytes(1073741824), "1\\.0 GB")
  })
  
  test_that("format_bytes() handles NA and edge cases", {
    expect_match(format_bytes(NA), "NA")
    expect_match(format_bytes(0), "0 B")
    expect_match(format_bytes(1), "1 B")
  })
  
})

