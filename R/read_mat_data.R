#' Read Eye-Tracking and Behavioral Data from MATLAB .mat Files
#'
#' @description
#' Reads `.mat` files containing eye-tracking samples and behavioral responses
#' from the CSN study. The files are expected to contain two top-level structures:
#' - `subjdata`: behavioral data (trials, responses, signals)
#' - `Edf2Mat`: eye-tracking data (samples, events, recordings)
#'
#' @param path Character path to the `.mat` file.
#' @param participant_id Optional participant identifier. If NULL, attempts to
#'   extract from filename (e.g., "CSN001" from "CSN001_data.mat").
#'
#' @return A list with four tibbles:
#'   - `samples`: High-frequency gaze samples (30,000 rows) with columns `id`,
#'     `t`, `x_px`, `y_px`, `pupil`, `eye`, `blink`, `inside_screen`.
#'   - `events`: Discrete events (132 rows) with columns `id`, `type`, `t`, `msg`,
#'     and parsed validation/behavioral fields when applicable.
#'   - `behavioral`: Trial-level behavioral data (60 rows) with columns `trial`,
#'     `id`, `signal_flag`, `signal_time`, `response_flag`, `response_time`,
#'     `reaction_time`, `image_index`, `clock_side`, `outcome`, etc.
#'   - `metadata`: Session-level metadata (1 row) including sampling rate,
#'     duration, trial count, clock position, etc.
#'
#' @details
#' The function handles both `steps` and `step` field variants in `subjdata`.
#' Times in the `.mat` file are in milliseconds and are preserved as-is.
#' Gaze positions from the second row of `gx`/`gy` matrices (right eye) are
#' extracted; the first row (left eye) contains NaNs for monocular recording.
#'
#' @examples
#' \dontrun{
#' mat_file <- system.file("extdata/synthetic/synthetic_01.mat",
#'                         package = "itrackvalr")
#' data <- read_mat_data(mat_file)
#' str(data, max.level = 1)
#' # List of 4
#' #  $ samples   : tibble [30,000 × 8]  - Gaze samples
#' #  $ events    : tibble [132 × 15]    - Event stream
#' #  $ behavioral: tibble [60 × 15]     - Trial-level behavioral
#' #  $ metadata  : tibble [1 × 11]      - Session metadata
#' }
#'
#' @export
read_mat_data <- function(path, participant_id = NULL) {
  
  # Validate file exists
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }
  
  # Extract participant ID from filename if not provided
  if (is.null(participant_id)) {
    participant_id <- extract_participant_id(path)
  }
  
  # Read .mat file
  cli::cli_alert_info("Reading {.file {basename(path)}} for participant {.val {participant_id}}")
  mat_data <- R.matlab::readMat(path)
  
  # Verify expected top-level structures
  if (!("subjdata" %in% names(mat_data)) || !("Edf2Mat" %in% names(mat_data))) {
    cli::cli_abort(c(
      "Invalid .mat file structure",
      "x" = "Expected 'subjdata' and 'Edf2Mat', found: {names(mat_data)}"
    ))
  }
  
  # Extract structures (R.matlab adds extra dimensions, need [,,1])
  subjdata <- mat_data$subjdata[,,1]
  edf2mat <- mat_data$Edf2Mat[,,1]
  
  # Parse behavioral data (events stream)
  behavioral_events <- parse_subjdata(subjdata, participant_id)
  
  # Parse eye-tracking samples
  samples <- parse_fsample(edf2mat$FSAMPLE, participant_id)
  
  # Parse events
  et_events <- parse_fevent(edf2mat$FEVENT, participant_id)
  
  # Combine behavioral and eye-tracking events
  events <- dplyr::bind_rows(behavioral_events, et_events) |>
    dplyr::arrange(t)
  
  # Extract metadata
  metadata <- extract_metadata(subjdata, edf2mat$RECORDINGS, participant_id)
  
  # Extract trial-level behavioral data (always - required for analyses)
  # This will work if behavioral.R is sourced or package is loaded
  behavioral <- tryCatch(
    extract_behavioral_trials(subjdata, participant_id),
    error = function(e) {
      cli::cli_warn("Could not extract behavioral trials: {e$message}")
      NULL
    }
  )
  
  n_trials <- if (!is.null(behavioral)) nrow(behavioral) else 0
  cli::cli_alert_success("Loaded {nrow(samples)} samples, {nrow(events)} events, {n_trials} trials")
  
  result <- list(
    samples = samples,
    events = events,
    metadata = metadata
  )
  
  # Add behavioral trials if successfully extracted
  if (!is.null(behavioral)) {
    result$behavioral <- behavioral
  }
  
  result
}

#' Extract participant ID from filename
#' @keywords internal
extract_participant_id <- function(path) {
  basename <- basename(path)
  # Try to extract CSN### or synthetic_##
  if (stringr::str_detect(basename, "CSN\\d{3}")) {
    return(stringr::str_extract(basename, "CSN\\d{3}"))
  } else if (stringr::str_detect(basename, "synthetic_\\d{2}")) {
    id_num <- stringr::str_extract(basename, "\\d{2}")
    return(paste0("SYN", id_num))
  } else {
    # Fallback: use filename without extension
    return(tools::file_path_sans_ext(basename))
  }
}

#' Parse subjdata structure into behavioral events
#' @keywords internal
parse_subjdata <- function(subjdata, participant_id) {
  
  # Extract basic fields
  n_trials <- as.integer(subjdata$nTrials[1])
  p_signal <- as.numeric(subjdata$pSignal[1])
  exp_begin <- as.numeric(subjdata$expBegin[1])
  exp_end <- as.numeric(subjdata$expEnd[1])
  
  # Extract behavioral matrices
  resps <- subjdata$resps  # n_trials × 2: [response_flag, response_time]
  # lr is a SCALAR (0 or 1) indicating which side clock is on for entire session
  # Per task.m line 260: lr = rand < 0.5
  lr_raw <- subjdata$lr
  lr <- if (length(lr_raw) == 1) as.numeric(lr_raw[1]) else as.numeric(lr_raw[[1]])
  img_ind <- as.vector(subjdata$img.ind)
  
  # Handle steps vs step field (both variants exist in the wild)
  if ("steps" %in% names(subjdata)) {
    steps <- subjdata$steps  # n_trials × 2: [signal_flag, signal_time]
  } else if ("step" %in% names(subjdata)) {
    steps <- subjdata$step
  } else {
    cli::cli_abort(c(
      "Missing signal timing field",
      "x" = "Expected 'steps' or 'step' in subjdata, found: {names(subjdata)}"
    ))
  }
  
  # Build events tibble
  events_list <- list()
  
  for (i in seq_len(n_trials)) {
    trial_num <- i
    
    # Signal events (if present)
    if (steps[i, 1] == 1) {
      events_list <- append(events_list, list(tibble::tibble(
        id = participant_id,
        type = "signal",
        trial = trial_num,
        t = steps[i, 2],
        signal_flag = 1,
        image_index = img_ind[i],
        clock_side = lr  # Scalar for entire session
      )))
    }
    
    # Response events (if present)
    if (resps[i, 1] == 1) {
      events_list <- append(events_list, list(tibble::tibble(
        id = participant_id,
        type = "response",
        trial = trial_num,
        t = resps[i, 2],
        response_flag = 1,
        image_index = img_ind[i],
        clock_side = lr  # Scalar for entire session
      )))
    }
    
    # Image onset/offset events will come from FEVENT
  }
  
  # Combine all behavioral events
  if (length(events_list) > 0) {
    events <- dplyr::bind_rows(events_list)
  } else {
    # Empty events tibble with correct schema
    events <- tibble::tibble(
      id = character(),
      type = character(),
      trial = integer(),
      t = numeric(),
      signal_flag = numeric(),
      image_index = numeric(),
      clock_side = numeric()
    )
  }
  
  events
}

#' Parse FSAMPLE structure into samples tibble
#' @keywords internal
parse_fsample <- function(fsample, participant_id) {
  
  # FSAMPLE fields may be nested in [,,1] structure
  if (is.list(fsample) && !is.null(dim(fsample))) {
    fs <- fsample[,,1]
  } else {
    fs <- fsample
  }
  
  # Extract fields - stored as matrices with dim 1×n or 2×n
  time <- as.vector(fs$time)  # Convert matrix to vector
  gx <- fs$gx  # 2 × n_samples matrix
  gy <- fs$gy  # 2 × n_samples matrix  
  pa <- fs$pa  # 2 × n_samples matrix
  
  # Extract right eye only (row 2, index 2 in R)
  # Left eye (row 1) contains NaN values for monocular recording
  x_px <- as.vector(gx[2, ])
  y_px <- as.vector(gy[2, ])
  pupil <- as.vector(pa[2, ])
  
  # Create samples tibble
  samples <- tibble::tibble(
    id = participant_id,
    t = time,
    x_px = x_px,
    y_px = y_px,
    pupil = pupil,
    eye = "RIGHT",
    blink = FALSE,  # Will be detected later from pupil == 0 or large gaps
    inside_screen = TRUE  # Will be validated later based on screen dimensions
  )
  
  samples
}

#' Parse FEVENT structure into events tibble
#' @keywords internal
parse_fevent <- function(fevent, participant_id) {
  
  # FEVENT may be nested in [,,1] structure
  if (is.list(fevent) && !is.null(dim(fevent))) {
    fe <- fevent[,,1]
  } else {
    fe <- fevent
  }
  
  # Extract event times
  event_times <- as.vector(fe$time)
  
  # Extract messages - R.matlab stores strings as deeply nested lists/matrices
  event_msgs_raw <- fe$msg
  
  # Convert nested list/matrix structure to character vector
  event_msgs <- vapply(seq_along(event_times), function(i) {
    msg_cell <- event_msgs_raw[1, i]
    # Navigate through the nested list/matrix structure
    if (is.list(msg_cell)) {
      inner <- msg_cell[[1]]
      if (is.matrix(inner) || is.array(inner)) {
        as.character(inner[1,1])
      } else if (is.list(inner)) {
        as.character(inner[[1]])
      } else {
        as.character(inner)
      }
    } else if (is.matrix(msg_cell)) {
      as.character(msg_cell[1,1])
    } else {
      as.character(msg_cell)
    }
  }, character(1))
  
  # Create base events tibble
  events <- tibble::tibble(
    id = participant_id,
    type = classify_event_type(event_msgs),
    t = event_times,
    msg = event_msgs
  )
  
  # Parse calibration messages to extract validation metrics
  events <- parse_calibration_fields(events)
  
  events
}

#' Classify event type from message string
#' @keywords internal
classify_event_type <- function(msgs) {
  dplyr::case_when(
    stringr::str_detect(msgs, "^!CAL VALIDATION") ~ "calibration",
    stringr::str_detect(msgs, "image_onset") ~ "image_onset",
    stringr::str_detect(msgs, "image_offset") ~ "image_offset",
    stringr::str_detect(msgs, "signal") ~ "signal",
    stringr::str_detect(msgs, "response") ~ "response",
    TRUE ~ "other"
  )
}

#' Parse calibration validation messages
#' @keywords internal
parse_calibration_fields <- function(events) {
  
  # Add placeholder columns for calibration metrics
  events <- events |>
    dplyr::mutate(
      validation_type = NA_character_,
      avg_err_deg = NA_real_,
      max_err_deg = NA_real_,
      offset_x_px = NA_real_,
      offset_y_px = NA_real_
    )
  
  # Parse calibration messages
  cal_rows <- which(events$type == "calibration")
  
  for (i in cal_rows) {
    msg <- events$msg[i]
    
    # Extract validation type (pre/post)
    if (stringr::str_detect(msg, "\\bpre\\b")) {
      events$validation_type[i] <- "pre"
    } else if (stringr::str_detect(msg, "\\bpost\\b")) {
      events$validation_type[i] <- "post"
    }
    
    # Extract avg_err (degrees)
    avg_match <- stringr::str_match(msg, "avg_err=([0-9.]+)")
    if (!is.na(avg_match[1,2])) {
      events$avg_err_deg[i] <- as.numeric(avg_match[1,2])
    }
    
    # Extract max_err (degrees)
    max_match <- stringr::str_match(msg, "max_err=([0-9.]+)")
    if (!is.na(max_match[1,2])) {
      events$max_err_deg[i] <- as.numeric(max_match[1,2])
    }
    
    # Extract offset (x,y) in pixels (handles negative values)
    offset_match <- stringr::str_match(msg, "offset=\\(([+-]?[0-9.]+),([+-]?[0-9.]+)\\)")
    if (!is.na(offset_match[1,1])) {
      events$offset_x_px[i] <- as.numeric(offset_match[1,2])
      events$offset_y_px[i] <- as.numeric(offset_match[1,3])
    }
  }
  
  events
}

#' Extract session metadata
#' @keywords internal
extract_metadata <- function(subjdata, recordings, participant_id) {
  
  # Recordings is also a nested list structure - extract it
  if (is.list(recordings) && !is.null(dim(recordings))) {
    rec <- recordings[,,1]
  } else {
    rec <- recordings
  }
  
  # Get image names (if available) - stored as nested list in matrix
  image_names <- if ("image.names" %in% names(subjdata)) {
    img_raw <- subjdata$image.names
    if (is.matrix(img_raw)) {
      vapply(seq_len(ncol(img_raw)), function(i) {
        as.character(img_raw[1, i][[1]])
      }, character(1))
    } else if (is.list(img_raw)) {
      vapply(img_raw, function(x) as.character(x[[1]]), character(1))
    } else {
      as.character(img_raw)
    }
  } else {
    NA_character_
  }
  
  # Extract clock_side (lr) - scalar for entire session
  lr_raw <- subjdata$lr
  clock_side <- if (length(lr_raw) == 1) as.numeric(lr_raw[1]) else as.numeric(lr_raw[[1]])
  
  tibble::tibble(
    id = participant_id,
    n_trials = as.integer(subjdata$nTrials[1]),
    p_signal = as.numeric(subjdata$pSignal[1]),
    clock_side = clock_side,  # 0 = left, 1 = right
    exp_begin = as.numeric(subjdata$expBegin[1]),
    exp_end = as.numeric(subjdata$expEnd[1]),
    sampling_rate_hz = as.numeric(rec$samplerate[1]),
    duration_ms = as.numeric(rec$duration[1]),
    recording_start = as.numeric(rec$start[1]),
    recording_end = as.numeric(rec$end[1]),
    image_names = list(image_names)
  )
}

