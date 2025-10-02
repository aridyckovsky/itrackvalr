# itrackvalr targets pipeline - PR-B: Full Eye-Tracking Pipeline
# Processes all participants from .mat ingestion through on-task classification

library(targets)
library(tarchetypes)

# Source all R modules
source("R/read_mat_data.R")
source("R/calibration.R")
source("R/behavioral.R")
source("R/export_helpers.R")
source("R/multi_participant.R")
source("R/multi_participant_polars.R")
source("R/utils_polars.R")
source("R/resampling.R")
source("R/clock_hand.R")
source("R/preprocessing.R")

# Set target options
tar_option_set(
  packages = c(
    "R.matlab",
    "dplyr",
    "tidyr",
    "tibble",
    "stringr",
    "cli",
    "rlang",
    "here",
    "fs",
    "readr",
    "broom",
    "config",
    "ggplot2",
    "scales"
  ),
  format = "rds",
  error = "continue"
)

# Define pipeline
list(
  # ========================================================================
  # STEP 1: DATA INGESTION
  # ========================================================================
  
  tar_target(
    mat_files,
    {
      # Use environment variable if set, otherwise default to testing fixtures
      data_dir <- Sys.getenv("ITRACKVALR_DATA_DIR", unset = "inst/extdata/synthetic")
      get_mat_files(data_dir)
    }
  ),
  
  tar_target(
    all_participant_data,
    read_all_participants(mat_files)
  ),
  
  # ========================================================================
  # STEP 2: AGGREGATE RAW DATA (with smart dispatch)
  # ========================================================================
  
  tar_target(
    all_samples,
    # Smart dispatch: auto-detects scale and uses polars for >10 participants
    # Returns tibble (can be cached by targets)
    aggregate_samples(all_participant_data)
  ),
  
  tar_target(
    all_events,
    aggregate_events(all_participant_data)
  ),
  
  tar_target(
    all_behavioral,
    {
      # Aggregate and classify outcomes
      behavioral_raw <- aggregate_behavioral(all_participant_data)
      classify_behavioral_outcomes(behavioral_raw)
    }
  ),
  
  tar_target(
    all_validation,
    aggregate_validation(all_participant_data)
  ),
  
  tar_target(
    all_metadata,
    aggregate_metadata(all_participant_data)
  ),
  
  # ========================================================================
  # STEP 3: VALIDATION ANALYSIS
  # ========================================================================
  
  tar_target(
    validation_summary,
    tryCatch(
      summarize_validation_relationships(all_validation),
      error = function(e) {
        cli::cli_warn("Validation summary skipped (constant data or n<3): {e$message}")
        NULL
      }
    )
  ),
  
  tar_target(
    zone_radii,
    {
      cfg <- config::get()
      compute_zone_radius(
        all_validation,
        strategy = cfg$validation$zone_strategy,
        scaling = cfg$validation$zone_scaling
      )
    }
  ),
  
  # ========================================================================
  # STEP 4: CALIBRATION & PREPROCESSING
  # ========================================================================
  
  tar_target(
    samples_calibrated,
    apply_calibration_offsets(
      all_samples,
      all_validation,
      method = "linear"
    )
  ),
  
  tar_target(
    samples_resampled,
    resample_samples(
      samples_calibrated,
      hz_standard = 500,
      gap_threshold = 20
    )
  ),
  
  # ========================================================================
  # STEP 5: CLOCK HAND DYNAMICS
  # ========================================================================
  
  tar_target(
    hand_positions,
    derive_hand_dynamics(
      metadata_df = all_metadata,
      events_df = all_events,
      cfg = config::get(),
      sampling_rate_hz = 500
    )
  ),
  
  tar_target(
    samples_with_hand,
    join_hand_positions(samples_resampled, hand_positions)
  ),
  
  # ========================================================================
  # STEP 6: DISTANCE & ON-TASK CLASSIFICATION
  # ========================================================================
  
  tar_target(
    samples_with_distance,
    compute_distance(samples_with_hand, use_adjusted = TRUE)
  ),
  
  tar_target(
    samples_binarized,
    binarize_on_task(samples_with_distance, zone_radii)
  ),
  
  # ========================================================================
  # STEP 7: TRIAL SEGMENTATION
  # ========================================================================
  
  tar_target(
    trial_segments,
    segment_trials(
      samples_binarized,
      all_events,
      all_behavioral
    )
  ),
  
  # ========================================================================
  # STEP 8: COHORT SUMMARIES
  # ========================================================================
  
  tar_target(
    cohort_behavioral_summary,
    summarize_behavioral_by_participant(all_behavioral)
  ),
  
  tar_target(
    cohort_summary,
    {
      # Ensure all preprocessing complete before summarizing
      trial_segments  # Dependency
      
      summary <- tibble::tibble(
        n_participants = nrow(all_metadata),
        total_samples_raw = nrow(all_samples),
        total_samples_binarized = nrow(samples_binarized),
        total_trial_samples = nrow(trial_segments),
        total_trials = nrow(all_behavioral),
        total_signals = sum(all_behavioral$signal_flag == 1),
        total_responses = sum(all_behavioral$response_flag == 1),
        mean_hit_rate = mean(cohort_behavioral_summary$hit_rate, na.rm = TRUE),
        mean_fa_rate = mean(cohort_behavioral_summary$false_alarm_rate, na.rm = TRUE),
        mean_d_prime = mean(cohort_behavioral_summary$d_prime, na.rm = TRUE),
        mean_rt = mean(cohort_behavioral_summary$mean_rt, na.rm = TRUE),
        mean_zone_radius_px = mean(zone_radii$r_px, na.rm = TRUE),
        p_on_task_overall = mean(samples_binarized$on_task, na.rm = TRUE)
      )
      
      cli::cli_h1("itrackvalr Pipeline Complete (PR-B)")
      cli::cli_h2("Data Ingestion")
      cli::cli_alert_success("Participants: {summary$n_participants}")
      cli::cli_alert_success("Raw samples: {summary$total_samples_raw}")
      cli::cli_alert_success("Trials: {summary$total_trials}")
      
      cli::cli_h2("Preprocessing")
      cli::cli_alert_success("Calibrated + resampled samples: {summary$total_samples_binarized}")
      cli::cli_alert_success("Mean zone radius: {round(summary$mean_zone_radius_px, 1)} px")
      cli::cli_alert_success("Overall p(on-task): {round(summary$p_on_task_overall * 100, 1)}%")
      
      cli::cli_h2("Trial Segmentation")
      cli::cli_alert_success("Trial-segmented samples: {summary$total_trial_samples}")
      
      cli::cli_h2("Behavioral Performance")
      cli::cli_alert_success("Hit rate: {round(summary$mean_hit_rate * 100, 1)}%")
      cli::cli_alert_success("FA rate: {round(summary$mean_fa_rate * 100, 1)}%")
      cli::cli_alert_success("d-prime: {round(summary$mean_d_prime, 2)}")
      cli::cli_alert_success("Mean RT: {round(summary$mean_rt, 0)} ms")
      
      summary
    }
  ),
  
  # ========================================================================
  # STEP 9: CREATE OUTPUT STRUCTURE
  # ========================================================================
  
  tar_target(
    output_dirs,
    {
      dirs <- create_output_dirs("output")
      # Ensure calibrated and preprocessed dirs exist
      fs::dir_create("output/calibrated")
      fs::dir_create("output/preprocessed")
      fs::dir_create("output/analysis")
      dirs
    }
  ),
  
  # ========================================================================
  # STEP 10: EXPORT ALL DATASETS
  # ========================================================================
  
  tar_target(
    export_all_data,
    {
      output_dirs  # Ensure directories exist
      
      files <- list()
      
      # === EXTRACTED (PR-A outputs) ===
      
      files$samples_raw <- export_pipeline_data(
        all_samples,
        stage = "extracted",
        name = "ALL_samples",
        base_dir = "output",
        formats = "parquet"
      )
      
      files$events <- export_pipeline_data(
        all_events,
        stage = "extracted",
        name = "ALL_events",
        base_dir = "output",
        formats = c("csv", "parquet")
      )
      
      files$behavioral <- export_pipeline_data(
        all_behavioral,
        stage = "extracted",
        name = "ALL_behavioral",
        base_dir = "output",
        formats = c("csv", "parquet")
      )
      
      files$metadata <- export_pipeline_data(
        all_metadata,
        stage = "extracted",
        name = "ALL_metadata",
        base_dir = "output",
        formats = "csv"
      )
      
      files$cohort_behav <- export_pipeline_data(
        cohort_behavioral_summary,
        stage = "extracted",
        name = "cohort_behavioral_summary",
        base_dir = "output",
        formats = "csv"
      )
      
      if (!is.null(validation_summary)) {
        files$cohort_val <- export_pipeline_data(
          validation_summary$global_summary,
          stage = "extracted",
          name = "cohort_validation_summary",
          base_dir = "output",
          formats = "csv"
        )
      }
      
      # === CALIBRATED (PR-B outputs) ===
      
      files$calibrated <- export_pipeline_data(
        samples_calibrated,
        stage = "calibrated",
        name = "ALL_samples_calibrated",
        base_dir = "output",
        formats = "parquet"
      )
      
      files$zone_radii <- export_pipeline_data(
        zone_radii,
        stage = "calibrated",
        name = "zone_radii",
        base_dir = "output",
        formats = "csv"
      )
      
      # === PREPROCESSED (PR-B outputs) ===
      
      files$resampled <- export_pipeline_data(
        samples_resampled,
        stage = "preprocessed",
        name = "ALL_samples_resampled",
        base_dir = "output",
        formats = "parquet"
      )
      
      files$hand_positions <- export_pipeline_data(
        hand_positions,
        stage = "preprocessed",
        name = "hand_positions",
        base_dir = "output",
        formats = "parquet"
      )
      
      files$binarized <- export_pipeline_data(
        samples_binarized,
        stage = "preprocessed",
        name = "ALL_samples_binarized",
        base_dir = "output",
        formats = "parquet"
      )
      
      files$trials <- export_pipeline_data(
        trial_segments,
        stage = "preprocessed",
        name = "trial_segments",
        base_dir = "output",
        formats = c("csv", "parquet")
      )
      
      unlist(files, use.names = FALSE)
    },
    format = "file"
  ),
  
  # ========================================================================
  # STEP 11: EXPORT MANIFEST
  # ========================================================================
  
  tar_target(
    export_manifest,
    {
      export_all_data  # Ensure all exports complete
      create_export_manifest("output")
    }
  ),
  
  # ========================================================================
  # STEP 12: VISUALIZATIONS & REPORTS (Optional - needs image data)
  # ========================================================================
  
  tar_target(
    basic_timecourse_plot,
    {
      # Create basic on-task timecourse plot (works without image data)
      trial_segments  # Dependency
      
      # Compute p(on-task) over time within trial
      timecourse <- trial_segments |>
        dplyr::filter(t_trial_ms >= 0, t_trial_ms <= 1000) |>
        dplyr::mutate(t_bin = floor(t_trial_ms / 50) * 50) |>
        dplyr::group_by(t_bin) |>
        dplyr::summarise(
          n_samples = dplyr::n(),
          n_on_task = sum(on_task == TRUE, na.rm = TRUE),
          n_valid = sum(!is.na(on_task)),
          p_on_task = n_on_task / n_valid,
          se = sqrt(p_on_task * (1 - p_on_task) / n_valid),
          .groups = "drop"
        )
      
      # Create plot
      fs::dir_create("output/reports")
      
      p <- ggplot2::ggplot(timecourse, ggplot2::aes(x = t_bin, y = p_on_task)) +
        ggplot2::geom_line(linewidth = 1, color = "#2c3e50") +
        ggplot2::geom_ribbon(
          ggplot2::aes(ymin = p_on_task - se, ymax = p_on_task + se),
          alpha = 0.2, fill = "#3498db"
        ) +
        ggplot2::labs(
          title = "On-Task Timecourse",
          subtitle = paste("N =", length(unique(trial_segments$id)), "participants,", 
                          length(unique(paste(trial_segments$id, trial_segments$trial))), "trials"),
          x = "Time since image onset (ms)",
          y = "Proportion on-task"
        ) +
        ggplot2::scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
        ggplot2::theme_minimal() +
        ggplot2::theme(
          plot.title = ggplot2::element_text(face = "bold", size = 14),
          plot.subtitle = ggplot2::element_text(color = "gray40")
        )
      
      plot_path <- "output/reports/ontask_timecourse.png"
      ggplot2::ggsave(plot_path, p, width = 8, height = 5, dpi = 300)
      
      cli::cli_alert_success("Saved on-task timecourse plot to {.file {plot_path}}")
      
      list(timecourse = timecourse, plot = p, plot_path = plot_path)
    }
  ),
  
  # ========================================================================
  # STEP 13: PER-PARTICIPANT GAZE VISUALIZATIONS
  # ========================================================================
  
  tar_target(
    participant_gaze_plots,
    {
      # Create gaze heatmap for each participant showing full session
      # Similar to csn_datacheck_03.m visualization
      samples_binarized  # Dependency
      all_metadata  # For clock_side info
      
      fs::dir_create("output/reports/participant_plots")
      
      cfg <- config::get()
      
      # Get unique participants
      participant_ids <- unique(all_metadata$id)
      
      plot_paths <- list()
      
      for (pid in participant_ids) {
        # Get participant data
        p_samples <- samples_binarized |>
          dplyr::filter(id == pid)
        
        p_meta <- all_metadata |>
          dplyr::filter(id == pid)
        
        # Screen dimensions
        screen_w <- cfg$screen$width_px
        screen_h <- cfg$screen$height_px
        
        # Clock dimensions (task.m lines 171-172)
        clock_diameter <- min(screen_w, screen_h) * cfg$clock$diameter_ratio
        
        # Clock and image positions based on clock_side (task.m lines 260-271)
        if (p_meta$clock_side == 0) {
          # Clock LEFT, Image RIGHT
          clock_center_x <- screen_w / 4
          image_center_x <- screen_w * 3 / 4
        } else {
          # Clock RIGHT, Image LEFT
          clock_center_x <- screen_w * 3 / 4
          image_center_x <- screen_w / 4
        }
        clock_center_y <- screen_h / 2
        image_center_y <- screen_h / 2
        
        # Image dimensions (task.m lines 178-179)
        image_w <- screen_w * 0.48
        image_h <- image_w * 0.75
        
        # Create clock circle coordinates
        theta <- seq(0, 2 * pi, length.out = 100)
        clock_circle <- tibble::tibble(
          x = clock_center_x + (clock_diameter / 2) * cos(theta),
          y = clock_center_y + (clock_diameter / 2) * sin(theta)
        )
        
        # Create image rectangle
        image_rect <- tibble::tibble(
          x = c(image_center_x - image_w/2, image_center_x + image_w/2, 
                image_center_x + image_w/2, image_center_x - image_w/2, 
                image_center_x - image_w/2),
          y = c(image_center_y - image_h/2, image_center_y - image_h/2,
                image_center_y + image_h/2, image_center_y + image_h/2,
                image_center_y - image_h/2)
        )
        
        # Create plot
        p <- ggplot2::ggplot() +
          # Gaze points (colored by on-task status)
          ggplot2::geom_point(
            data = p_samples,
            ggplot2::aes(x = x_px, y = y_px, color = on_task),
            size = 0.3,
            alpha = 0.1
          ) +
          # Clock circle
          ggplot2::geom_path(
            data = clock_circle,
            ggplot2::aes(x = x, y = y),
            color = "black",
            linewidth = 1.5
          ) +
          # Image rectangle
          ggplot2::geom_path(
            data = image_rect,
            ggplot2::aes(x = x, y = y),
            color = "black",
            linewidth = 1.5,
            linetype = "dashed"
          ) +
          # Screen boundaries
          ggplot2::geom_rect(
            ggplot2::aes(xmin = 0, xmax = screen_w, ymin = 0, ymax = screen_h),
            fill = NA,
            color = "gray50",
            linewidth = 0.5
          ) +
          ggplot2::scale_color_manual(
            values = c("TRUE" = "#2ecc71", "FALSE" = "#e74c3c"),
            na.value = "gray70",
            labels = c("TRUE" = "On-task", "FALSE" = "Off-task", "NA" = "Blink/Missing"),
            name = "Gaze status"
          ) +
          ggplot2::coord_fixed(ratio = 1) +
          ggplot2::scale_x_continuous(limits = c(0, screen_w)) +
          ggplot2::scale_y_continuous(limits = c(0, screen_h)) +
          ggplot2::labs(
            title = paste("Gaze Distribution:", pid),
            subtitle = paste(
              "Clock:", if (p_meta$clock_side == 0) "LEFT" else "RIGHT",
              "| On-task:", round(mean(p_samples$on_task, na.rm = TRUE) * 100, 1), "%",
              "| N samples:", nrow(p_samples)
            ),
            x = "X position (px)",
            y = "Y position (px)"
          ) +
          ggplot2::theme_minimal() +
          ggplot2::theme(
            plot.title = ggplot2::element_text(face = "bold"),
            legend.position = "bottom",
            aspect.ratio = screen_h / screen_w
          )
        
        # Save plot
        plot_path <- file.path("output/reports/participant_plots", paste0(pid, "_gaze_fullsession.png"))
        ggplot2::ggsave(plot_path, p, width = 10, height = 8, dpi = 150)
        
        plot_paths[[pid]] <- plot_path
      }
      
      cli::cli_alert_success(
        "Created gaze visualizations for {length(plot_paths)} participant{?s}"
      )
      
      unlist(plot_paths)
    },
    format = "file"
  )
)
