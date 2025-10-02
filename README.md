<!--
*** We're using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc.
-->

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stars][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- Make sure to update to main repo when merged -->

[![R-CMD-check](https://github.com/aridyckovsky/itrackvalr/workflows/R-CMD-check/badge.svg)](https://github.com/aridyckovsky/itrackvalr/actions)
[![Codecov test coverage](https://codecov.io/gh/aridyckovsky/itrackvalr/branch/main/graph/badge.svg)](https://app.codecov.io/gh/aridyckovsky/itrackvalr?branch=main)

# itrackvalr: Toolkit to analyze value by tracking eye gaze (in R)

The `itrackvalr` package provides a collection of functions that make it easier to work with the various data sources used in value-based eye-tracking experiments.

## Overview

`itrackvalr` processes and analyzes eye-tracking data from the **CSN (Clock-Signal-Noise) study**, a sustained attention task using the **EyeLink 1000 Plus** eye tracker in **remote mode** (monocular right eye tracking, no chinrest, up to 1000 Hz sampling).

### Key Features

- ✅ **Multi-participant processing**: Process entire cohorts (57 CSN participants) with aggregated datasets
- ✅ **Complete data extraction**: Eye-tracking samples, events, trial-level behavioral data, and validation metrics
- ✅ **.mat file ingestion**: Reads MATLAB files containing `subjdata` (behavioral) and `Edf2Mat` (eye-tracking)
- ✅ **Validation analysis**: Pre/post calibration metrics, offsets, zone-of-uncertainty calculations
- ✅ **Behavioral outcomes**: Hit/miss/false-alarm classification with d-prime and reaction times
- ✅ **Reproducible pipeline**: `targets`-based workflow with organized data exports (CSV + Parquet)
- ✅ **PR-B Complete**: Calibration offsets, resampling, clock-hand dynamics, on/off-task binarization, model-free timecourses
- ✅ **Performance optimized**: Polars integration for efficient large-scale processing (90M samples, <8 GB RAM)
- 🔄 **Coming in PR-C**: Hierarchical models, sensitivity testing, equivalence analyses

---

## TODO Items (From Original Development)

Plots for each tier of thresholding, such as 1.5 degrees and 2.5 degrees. Write summaries of how validation-revalidation participant groups look. Start a separate RMarkdown to generate per-participant summaries.

- [ ] What groups of participants are we using based on thresholds?
- [ ] How do we do dimensional reduction?
- [ ] Apply offsets to gx/gy THEN flip to consistent side for all participants

**Status**: These will be addressed in PR-B (calibration/binarization) and PR-C (analyses).

---

## Hardware Configuration

The CSN study uses the [EyeLink 1000 Plus](https://www.hse.ru/mirror/pubs/share/560338728.pdf) configured in **desktop mount's monocular remote mode**:

- **Tracking**: Right eye only, without chinrest
- **Sampling**: 500 Hz or 1000 Hz (configurable)
- **Remote mode**: Uses a target sticker on participant's forehead for head distance measurement
- **Lens**: 25 mm remote lens (better quality than standard 16 mm)
- **Task**: Mackworth Clock Task with 1% signal probability (double movements)

### Data Storage

Eye-tracking and behavioral data are saved as **MATLAB `.mat` files** with two structures:

1. **`subjdata`** (behavioral):

   - `nTrials`: Number of trials (3,600 for real task, 60 for synthetic)
   - `pSignal`: Signal probability (0.01 = 1%)
   - `lr`: Clock position - SCALAR (0=left, 1=right) for entire session
   - `resps`: (n_trials × 2) matrix - [response_flag, response_time_ms]
   - `steps`: (n_trials × 2) matrix - [signal_flag, signal_time_ms]
   - `img_ind`: Image indices per trial
   - `image_names`: List of image filenames
   - `expBegin`, `expEnd`: Session start/end timestamps

2. **`Edf2Mat`** (eye-tracking):
   - `FSAMPLE`: Gaze samples - `time`, `gx`, `gy` (2-row matrices), `pa` (pupil area)
   - `FEVENT`: Event messages (calibrations, image onsets/offsets)
   - `RECORDINGS`: Metadata (duration, sampling rate)

---

## Prerequisites

You must have R (>= 4.5.0) and RStudio installed on your computer.

---

## Installation

### For End Users

**Requirements**:

- **R >= 4.5.0** (tested with R 4.5.1)
- Recommended: RStudio

**Install from GitHub**:

```r
# Install remotes if needed
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

# Install itrackvalr
remotes::install_github("aridyckovsky/itrackvalr")
```

### Setup for Project Team (Development)

Clone this repository into your local project folder using GitHub Desktop or via the command line using:

```sh
git clone https://github.com/sokolhessnerlab/itrackvalr.git
cd itrackvalr
```

Then, open the `itrackvalr` directory and double-click on `itrackvalr.Rproj` to launch the project in RStudio. When RStudio first loads the project, it will source the included `.Rprofile` to configure helpful defaults for your session.

### Loading Package Dependencies

We use the [`renv` package](https://rstudio.github.io/renv/index.html) to manage packages used for developing and using `itrackvalr`. To install the package dependencies for this project, run the following restoration command in the R console.

```r
renv::restore()
```

The dependencies are tracked by version in the `renv.lock` file. This includes:

- **Core dependencies** (19 packages): dplyr, ggplot2, targets, cli, etc.
- **Dev tools** (17 packages): roxygen2, devtools, testthat, usethis, etc.
- **Performance** (2 packages): polars, tidypolars (from R-universe for large-scale processing)

If during development you install a new package dependency, add it to `DESCRIPTION` and run `renv::snapshot()` to update the lock file.

### Participant Data

For the current studies, participant data is stored on a shared drive at the University of Denver. If you plan to work with participant data during your session, you must connect to the data separately from this package from whichever machine you are working from.

If working remotely, a secure connection to participant data requires connecting to the DU VPN and then mounting the shared drive to your computer.

Configure the data path in `config.yml`:

```yaml
default:
  path:
    data: "/Volumes/shlab/Projects/CSN/data" # Mounted drive path
```

### Development Workflow

#### Quick Start

```r
# Load package for development (without installing)
devtools::load_all()

# Run the complete pipeline
source("run_pipeline.R")
run_itrackvalr_pipeline()

# Run tests
testthat::test_dir("tests/testthat")
```

#### Building the Package

**Generate Documentation**:

```r
# Update all .Rd files from roxygen2 comments
roxygen2::roxygenise()

# Or using devtools
devtools::document()
```

This reads the `#'` roxygen comments in your R functions and:

- Generates `.Rd` files in `man/`
- Updates `NAMESPACE` with exports
- Updates `DESCRIPTION` RoxygenNote field

**Check Package**:

```r
# Run R CMD check (comprehensive validation)
devtools::check()

# This checks for:
# - Documentation completeness
# - Code quality issues
# - Test failures
# - CRAN compliance
```

**Build Package**:

```r
# Build source package (.tar.gz)
devtools::build()

# Build binary package (for your OS)
devtools::build(binary = TRUE)

# Install locally from source
devtools::install()
```

**Update Dependencies**:

```r
# After adding new package to DESCRIPTION
renv::install("newpackage")

# Update lockfile
renv::snapshot()
```

#### Complete Development Cycle

```r
# 1. Make code changes to R/*.R files

# 2. Update roxygen2 documentation
roxygen2::roxygenise()

# 3. Load updated code
devtools::load_all()

# 4. Run tests
testthat::test_dir("tests/testthat")

# 5. Run pipeline to verify
source("run_pipeline.R")
run_itrackvalr_pipeline()

# 6. Check package compliance
devtools::check()

# 7. Commit changes
# git add R/ man/ NAMESPACE tests/
# git commit -m "Description of changes"
```

#### Roxygen2 Quick Reference

**Function documentation template**:

```r
#' Function Title (One Line)
#'
#' @description
#' Detailed description of what the function does.
#'
#' @param param_name Description of parameter (type and purpose)
#' @param another_param Another parameter description
#'
#' @return Description of what the function returns, including:
#'   - Column names for tibbles
#'   - Data types
#'   - Special values (NA, NULL)
#'
#' @details
#' Additional implementation details, formulas, references to task.m
#'
#' @examples
#' \dontrun{
#' result <- my_function(param1, param2)
#' }
#'
#' @export
my_function <- function(param_name, another_param) {
  # Function body
}
```

**Roxygen tags used in itrackvalr**:

- `@export` - Make function available to users
- `@keywords internal` - Internal helper (not exported)
- `@param` - Document parameters
- `@return` - Document return value
- `@details` - Implementation notes, formulas, task.m references
- `@examples` - Usage examples (use `\dontrun{}` for file-dependent code)

#### Package Installation from Source

After building, install the package:

```r
# Install from local source
devtools::install()

# Or from GitHub (after merging PR-B)
remotes::install_github("aridyckovsky/itrackvalr", ref = "main")

# Install specific branch during development
remotes::install_github("aridyckovsky/itrackvalr", ref = "refactor/2025-revival")
```

#### Continuous Integration

PR-B includes GitHub Actions workflow (`.github/workflows/targets-pipeline.yml`):

- Runs on push/PR to main or refactor/2025-revival
- Validates pipeline with `tar_validate()`
- Checks pipeline manifest

To run locally:

```r
# Validate pipeline structure
targets::tar_validate()

# Check manifest
targets::tar_manifest()

# Verify all outdated
targets::tar_outdated()  # Should be empty after tar_make()
```

---

## Quick Start

### Single Participant

```r
library(itrackvalr)

# Read a .mat file
mat_file <- system.file("extdata/synthetic/synthetic_01.mat",
                         package = "itrackvalr")
data <- read_mat_data(mat_file)

# Inspect structure
str(data, max.level = 1)
#> List of 4
#>  $ samples   : tibble [30,000 × 8]  - Gaze samples (500 Hz × 60 sec)
#>  $ events    : tibble [132 × 14]    - Calibrations, signals, responses, images
#>  $ behavioral: tibble [60 × 17]     - Trial-level with outcomes classified
#>  $ metadata  : tibble [1 × 11]      - Session info (clock_side, sampling_rate, etc.)

# View gaze samples
head(data$samples)
#> # A tibble: 6 × 8
#>   id        t x_px  y_px pupil eye   blink inside_screen
#>   <chr> <dbl> <dbl> <dbl> <dbl> <chr> <lgl> <lgl>
#> 1 SYN01     0  547.  384. 1500. RIGHT FALSE TRUE
#> 2 SYN01     2  594.  384. 1490. RIGHT FALSE TRUE
#> ...

# View behavioral trials
head(data$behavioral)
#> # A tibble: 6 × 17
#>   trial id    p_signal clock_side signal_flag signal_time response_flag response_time
#>   <dbl> <chr>    <dbl>      <dbl>       <dbl>       <dbl>         <dbl>         <dbl>
#> 1     1 SYN01     0.01          0           0          NA             1           687
#> 2     2 SYN01     0.01          0           0          NA             0            NA
#> ...
#>   image_index reaction_time outcome         is_hit is_miss is_false_alarm
#>         <dbl>         <dbl> <chr>           <lgl>  <lgl>   <lgl>
#> 1           4            NA false_alarm     FALSE  FALSE   TRUE
#> 2           5            NA correct_reject  FALSE  FALSE   FALSE
#> ...

# Classify behavioral outcomes
classified <- classify_behavioral_outcomes(data$behavioral)
summary_stats <- summarize_behavioral(classified)
print(summary_stats)
#> Shows: n_hits, n_misses, n_false_alarms, hit_rate, d_prime, mean_rt, etc.
```

### Validation Analysis

```r
# Extract calibration metrics
validation_df <- parse_validation_msgs(data$events)
validation_df
#> # A tibble: 2 × 8
#>   id    time type  avg_err_deg max_err_deg offset_x_px offset_y_px raw_msg
#>   <chr> <dbl> <chr>       <dbl>       <dbl>       <dbl>       <dbl> <chr>
#> 1 SYN01     0 pre           0.5         1.0          10          20 !CAL VALIDATION pre...
#> 2 SYN01 61000 post          0.6         1.2          12          18 !CAL VALIDATION post...

# Analyze pre vs post validation
validation_summary <- summarize_validation_relationships(validation_df)
validation_summary$global_summary
#> Shows: pre_mean, post_mean, mean_diff, sd_diff for errors and offsets
```

---

## Performance Optimization with Polars

**NEW in PR-B**: `itrackvalr` uses [polars](https://pola.rs) for efficient processing of large-scale datasets through the [tidypolars](https://tidypolars.etiennebacher.com/) R package.

### Why Polars?

The full CSN cohort contains **~90 million gaze samples** (57 participants × ~1.8M samples each):

| Approach          | Memory Usage | Processing Time | Dataset Limit   |
| ----------------- | ------------ | --------------- | --------------- |
| **dplyr** (eager) | >10 GB RAM   | 5-10 minutes    | Limited by RAM  |
| **polars** (lazy) | <2 GB RAM    | <1 minute       | Larger than RAM |

### Smart Dispatch (Auto-Detection)

The package automatically chooses the most efficient backend based on dataset size:

```r
# Small scale (≤10 participants) → uses dplyr (fast enough)
mat_files <- get_mat_files("inst/extdata/synthetic")
participant_data <- read_all_participants(mat_files)
samples <- aggregate_samples(participant_data)  # Returns tibble
class(samples)  #> "tbl_df"

# Large scale (>10 participants) → uses polars (10-15x faster)
mat_files <- get_mat_files("/Volumes/shlab/Projects/CSN/data")
participant_data <- read_all_participants(mat_files)
samples_lf <- aggregate_samples(participant_data)  # Returns LazyFrame
class(samples_lf)  #> "polars_lazy_frame"
```

### Lazy Evaluation

Polars LazyFrames build a query plan without loading data into memory:

```r
# All operations remain lazy (data not loaded)
samples_processed <- samples_lf |>
  apply_calibration_offsets(validation_df, method = "linear") |>
  resample_samples(hz_standard = 500) |>
  compute_distance(use_adjusted = TRUE) |>
  binarize_on_task(zone_radii)

# Stream directly to disk (never loads 90M rows into memory!)
sink_parquet(samples_processed, "output/preprocessed/samples.parquet")

# OR materialize to tibble for interactive work
samples_tbl <- to_tibble(samples_processed)  # Computes the query
```

### Installation

Polars packages are installed from **R-universe** (not CRAN):

```r
# Repositories already configured in .Rprofile
renv::restore()  # Installs polars/tidypolars automatically

# Or install manually
options(repos = c(
  CRAN = "https://cloud.r-project.org",
  "R-multiverse" = "https://community.r-multiverse.org"
))
install.packages(c("polars", "tidypolars"))
```

### When to Use Which Backend

| Situation                              | Backend              | Returns   | Best For               |
| -------------------------------------- | -------------------- | --------- | ---------------------- |
| Development/testing (≤10 participants) | dplyr                | tibble    | Interactive analysis   |
| Production (>10 participants)          | polars               | LazyFrame | Memory efficiency      |
| Force dplyr                            | `use_polars = FALSE` | tibble    | Debugging, small scale |
| Force polars                           | `use_polars = TRUE`  | LazyFrame | Benchmarking           |

### Compatibility

All PR-B functions support **both eager (tibble) and lazy (LazyFrame) inputs**:

- `apply_calibration_offsets()` - Auto-detects input type
- `resample_samples()` - Auto-detects input type
- `compute_distance()` - Auto-detects input type
- `binarize_on_task()` - Auto-detects input type

The pipeline seamlessly switches between backends based on scale.

---

## Multi-Participant Pipeline

### Run Complete Pipeline (All Participants)

The default pipeline processes **all** `.mat` files and creates aggregated datasets:

```r
library(targets)

# Run the complete multi-participant pipeline
tar_make()

# This will:
# 1. Find all .mat files in configured data directory
# 2. Process each participant (samples, events, behavioral, validation)
# 3. Aggregate data across all participants
# 4. Generate cohort-level summaries
# 5. Export datasets to output/ directory

# View pipeline structure
tar_visnetwork()

# Access aggregated results
all_samples <- tar_read(all_samples)       # 150,000 samples (5 participants)
all_behavioral <- tar_read(all_behavioral) # 300 trials
cohort_summary <- tar_read(cohort_summary) # Cohort statistics
```

### Configure for Real CSN Data

Edit `config.yml` to point to your data directory:

```yaml
default:
  path:
    data: "/Volumes/shlab/Projects/CSN/data" # Your mounted drive path
  participants:
    id_prefix: "CSN"
    total: 57
    incomplete: 7 # Participants with incomplete data
```

Then update `_targets.R` to use the configured path:

```r
# In _targets.R, change:
tar_target(
  mat_files,
  get_mat_files(config::get()$path$data)  # Uses config.yml path
)
```

### Output Directory Structure

The pipeline exports data to organized directories:

```
output/
├── raw/                    # Archival copies of .mat files (future)
├── extracted/              # ✅ Current: Extracted from .mat files
│   ├── ALL_samples.parquet          # 150k samples (all participants)
│   ├── ALL_events.csv/.parquet      # All events combined
│   ├── ALL_behavioral.csv/.parquet  # All trials combined
│   ├── ALL_metadata.csv             # Participant metadata
│   ├── cohort_behavioral_summary.csv    # Per-participant statistics
│   ├── cohort_validation_summary.csv    # Validation analysis
│   └── {ID}_*.csv/.parquet          # Individual participant files (optional)
├── calibrated/             # PR-B: After calibration offsets applied
├── preprocessed/           # PR-B: Resampled, binarized data
├── analysis/               # PR-C: Model outputs
├── reports/                # PR-B/C: Figures and reports
└── MANIFEST.csv            # Catalog of all exported files
```

### Access Exported Data

```r
# Read aggregated datasets
library(readr)
library(arrow)

# Aggregated samples (Parquet recommended for large files)
all_samples <- arrow::read_parquet("output/extracted/ALL_samples.parquet")
# 150,000 rows for 5 participants (or 9 million for 57 real participants!)

# Aggregated behavioral data
all_behavioral <- read_csv("output/extracted/ALL_behavioral.csv")
# 300 trials (60 per participant × 5)

# Cohort summaries
cohort_behav <- read_csv("output/extracted/cohort_behavioral_summary.csv")
# Per-participant: hits, misses, d-prime, hit rate, reaction times

# File manifest
manifest <- read_csv("output/MANIFEST.csv")
# Shows all exported files with sizes and timestamps
```

### Single Participant Mode (Development)

For testing or debugging with one participant:

```r
# Use single-participant pipeline
targets::tar_make(script = "_targets_single.R")

# Or run manually
data <- read_mat_data("inst/extdata/synthetic/synthetic_01.mat")
validation <- parse_validation_msgs(data$events)
behavioral_summary <- summarize_behavioral(
  classify_behavioral_outcomes(data$behavioral)
)
```

---

## Data Structure

### Samples (`data$samples`)

**High-frequency gaze samples** - 30,000 rows per participant (500 Hz × 60 sec):

| Column          | Type | Description                                       |
| --------------- | ---- | ------------------------------------------------- |
| `id`            | chr  | Participant identifier (e.g., "SYN01", "CSN001")  |
| `t`             | dbl  | Timestamp in milliseconds from session start      |
| `x_px`          | dbl  | Horizontal gaze position (pixels)                 |
| `y_px`          | dbl  | Vertical gaze position (pixels)                   |
| `pupil`         | dbl  | Pupil area (arbitrary units)                      |
| `eye`           | chr  | Always "RIGHT" (monocular recording)              |
| `blink`         | lgl  | Blink flag (will be populated in PR-B)            |
| `inside_screen` | lgl  | Screen boundary check (will be validated in PR-B) |

**Additional columns (PR-B)**:

- `x_px_adj`, `y_px_adj`: Calibration-corrected coordinates
- `dist_to_tip_px`: Distance to clock hand tip (pixels)
- `on_task`: Boolean - within zone of uncertainty (TRUE/FALSE/NA)

### Events (`data$events`)

**Discrete occurrences** - ~132 rows per participant:

**Event Types**:

- `calibration` (2 per participant): Pre/post validation messages
- `signal` (~1% of trials): Double movement occurrences
- `response` (~varies): Spacebar presses
- `image_onset` (n_trials): Image presentations
- `image_offset` (n_trials): Image removals

**Columns for calibration events**:

- `validation_type`: "pre" or "post"
- `avg_err_deg`, `max_err_deg`: Validation errors in degrees
- `offset_x_px`, `offset_y_px`: Calibration offsets in pixels
- `raw_msg`: Original EyeLink message

**Columns for behavioral events**:

- `trial`: Trial number
- `signal_flag`, `response_flag`: 1 when present
- `image_index`: Which image was shown
- `clock_side`: 0 (left) or 1 (right) - constant for session

### Behavioral (`data$behavioral`)

**Trial-level behavioral data** - 60 rows per participant (or 3,600 for real task):

| Column                                                        | Type | Description                                                  |
| ------------------------------------------------------------- | ---- | ------------------------------------------------------------ |
| `trial`                                                       | int  | Trial number (1 to n_trials)                                 |
| `id`                                                          | chr  | Participant identifier                                       |
| `p_signal`                                                    | dbl  | Signal probability (0.01 = 1%)                               |
| `clock_side`                                                  | dbl  | Clock position: 0 (left) or 1 (right) - constant for session |
| `signal_flag`                                                 | int  | 1 if signal occurred, 0 otherwise                            |
| `signal_time`                                                 | dbl  | Time of double movement (ms), or NA                          |
| `response_flag`                                               | int  | 1 if participant responded, 0 otherwise                      |
| `response_time`                                               | dbl  | Time of response (ms), or NA                                 |
| `reaction_time`                                               | dbl  | response_time - signal_time (for hits)                       |
| `image_index`                                                 | int  | Which image was shown (1-10 for synthetic, 1-N for real)     |
| `task_begin`                                                  | dbl  | Experiment start timestamp                                   |
| `task_end`                                                    | dbl  | Experiment end timestamp                                     |
| `outcome`                                                     | chr  | "hit", "miss", "false_alarm", or "correct_rejection"         |
| `is_hit`, `is_miss`, `is_false_alarm`, `is_correct_rejection` | lgl  | Boolean flags                                                |

**Outcome Classification** (per task.m lines 661-667):

- **Hit**: Signal present AND response within 8 seconds
- **Miss**: Signal present but no (timely) response
- **False Alarm**: No signal but response occurred
- **Correct Rejection**: No signal, no response

### Metadata (`data$metadata`)

**Session-level information** - 1 row per participant:

- `id`: Participant identifier
- `n_trials`: Number of trials (60 synthetic, 3600 real)
- `p_signal`: Signal probability (0.01)
- `clock_side`: Clock position (0 or 1) - **SCALAR for entire session**
- `sampling_rate_hz`: Eye-tracker sampling rate (500 or 1000 Hz)
- `duration_ms`: Session duration in milliseconds
- `exp_begin`, `exp_end`: Timestamps
- `image_names`: List of image filenames used

---

## Pipeline Usage

### Recommended: Use `run_pipeline.R`

Process all participants with automatic configuration:

```r
# Load the pipeline runner
source("run_pipeline.R")

# Run with test fixtures (5 participants, fast)
run_itrackvalr_pipeline()

# Run with 57-participant cohort (polars auto-selected)
run_itrackvalr_pipeline(data_dir = "inst/extdata/synthetic_cohort")

# Run with real data
run_itrackvalr_pipeline(data_dir = "/Volumes/shlab/Projects/CSN/data")

# Clean rebuild
run_itrackvalr_pipeline(clean_start = TRUE)
```

### Alternative: Direct `targets` Usage

```r
library(targets)

# Set data directory (optional - defaults to inst/extdata/synthetic)
Sys.setenv(ITRACKVALR_DATA_DIR = "inst/extdata/synthetic_cohort")

# Run pipeline
tar_make()

# View progress
tar_progress()

# Access results
samples_binarized <- tar_read(samples_binarized)  # On/off-task classified
trial_segments <- tar_read(trial_segments)        # Trial-level data
cohort_summary <- tar_read(cohort_summary)        # Overall statistics
```

### Exported Data Files

After running the pipeline, find exported data in `output/extracted/`:

**Extracted** (`output/extracted/` - PR-A):

- `ALL_samples.parquet` - Raw gaze samples
- `ALL_events.csv` + `.parquet` - All events
- `ALL_behavioral.csv` + `.parquet` - All trials with outcomes classified
- `ALL_metadata.csv` - Participant information
- `cohort_behavioral_summary.csv` - Per-participant statistics
- `cohort_validation_summary.csv` - Validation analysis

**Calibrated** (`output/calibrated/` - PR-B):

- `ALL_samples_calibrated.parquet` - After offset application
- `zone_radii.csv` - Per-participant zone radii

**Preprocessed** (`output/preprocessed/` - PR-B):

- `ALL_samples_resampled.parquet` - Uniform 500Hz grid
- `ALL_samples_binarized.parquet` - With on_task classification
- `hand_positions.parquet` - Clock hand tip trajectories
- `trial_segments.parquet` - Trial-level segmented data

**Reports** (`output/reports/` - PR-B):

- `ontask_timecourse.png` - Cohort-level p(on-task) over time
- `participant_plots/` - Per-participant gaze distributions (57 plots)

**Manifest**: `MANIFEST.csv` - Complete catalog with sizes/timestamps

Read exported data:

```r
# In R
library(arrow)
samples <- read_parquet("output/extracted/ALL_samples.parquet")
behavioral <- readr::read_csv("output/extracted/ALL_behavioral.csv")

# In Python
import pandas as pd
samples = pd.read_parquet("output/extracted/ALL_samples.parquet")
behavioral = pd.read_csv("output/extracted/ALL_behavioral.csv")
```

### Alternative: Single-Participant Pipeline

For development or debugging:

```r
# Use single-participant pipeline variant
targets::tar_make(script = "_targets_single.R")

# Processes one participant with detailed outputs
```

See [`PIPELINES.md`](PIPELINES.md) for details on pipeline variants.

---

## Configuration

### Configure for Real Data

Edit `config.yml` to specify your data paths and parameters:

```yaml
default:
  path:
    data: "/Volumes/shlab/Projects/CSN/data" # Your data directory
  participants:
    id_prefix: "CSN" # Participant ID prefix
    total: 57 # Total participants
    incomplete: 7 # Participants with incomplete data
  screen:
    width_px: 1024 # Screen resolution
    height_px: 768
    viewing_distance_mm: 650 # Eye-to-screen distance
  clock:
    diameter_ratio: 0.333 # From task.m
    hand_length_ratio: 0.45
    increment_deg: 3.41
  validation:
    response_window_ms: 8000 # Valid response window (8 seconds)
    zone_strategy: "average" # "average", "maximum", or "linear"
```

### Screen Parameters

These are used for degree-to-pixel conversions (PR-B):

- `width_px`, `height_px`: Screen resolution (typically 1024×768)
- `width_mm`, `height_mm`: Physical screen dimensions
- `viewing_distance_mm`: Eye-to-screen distance (typically 650mm for remote mode)

### Clock Parameters

From `matlab/task.m` for clock-hand calculations (PR-B):

- `diameter_ratio`: Circle diameter as fraction of screen (0.333 = 1/3)
- `hand_length_ratio`: Hand length as fraction of diameter (0.45)
- `increment_deg`: Angular increment per movement (3.41°)

---

## Testing

Comprehensive test suite with synthetic `.mat` fixtures:

```r
# Run all tests (222 tests)
testthat::test_dir("tests/testthat")

# Run specific test suites
testthat::test_file("tests/testthat/test-behavioral.R")   # 61 tests
testthat::test_file("tests/testthat/test-calibration.R")  # 54 tests
testthat::test_file("tests/testthat/test-polars.R")        # 39 tests (PR-B)
testthat::test_file("tests/testthat/test-read_mat_data.R") # 42 tests
testthat::test_file("tests/testthat/test-data-quality.R")  # 16 tests (PR-B)
```

**Current coverage**:

- ✅ 222 tests passing (133 from PR-A, 89 from PR-B)
- ✅ 0 failures, 0 warnings
- ✅ Covers: .mat ingestion, validation, behavioral, calibration, resampling, clock hand dynamics, preprocessing, polars integration, data quality

---

## Data Processing Stages

### PR-A: Data Ingestion ✅ (Current)

**Input**: `.mat` files (subjdata + Edf2Mat)

**Processes**:

1. Read and parse .mat files
2. Extract gaze samples (30k per participant at 500 Hz)
3. Parse events (calibrations, signals, responses, images)
4. Extract trial-level behavioral data
5. Classify behavioral outcomes (hit/miss/FA/CR)
6. Parse validation messages
7. Generate summaries

**Output**: `output/extracted/`

- Per-participant and aggregated datasets
- CSV (human-readable) + Parquet (efficient)
- Behavioral summaries with d-prime, hit rates, reaction times

### PR-B: Calibration & Preprocessing ✅ (Complete)

**Input**: Extracted data from PR-A

**Implemented**:

1. ✅ Apply calibration offsets (linear interpolation pre→post)
2. ✅ Resample to 500Hz uniform grid with gap detection
3. ✅ Compute clock-hand tip positions (respects LEFT/RIGHT positioning)
4. ✅ Calculate Euclidean distance from gaze to clock-hand tip
5. ✅ Binarize into on-task/off-task using zone of uncertainty (50% on-task)
6. ✅ Segment data into 1-second image-presentation trials
7. ✅ Generate visualizations (timecourse plots, gaze distributions)

**Output**: `output/calibrated/`, `output/preprocessed/`, `output/reports/`

**Performance**: With polars integration, processes 57 participants x 60 trials in 1m 17s using <2 GB RAM

### PR-C: Model-Based Analyses 🔄 (Future)

**Input**: Preprocessed data from PR-B

**Will implement**:

1. Behavioral regression models (hits ~ signal_delay + covariates)
2. Hierarchical logistic models (on_task ~ time + arousal + valence)
3. Sensitivity analyses (varying zone radius, offset strategies)
4. Equivalence testing (golden metrics for dependency upgrades)

**Output**: `output/analysis/`, `output/reports/`

---

## Scaling: Synthetic → Real Data

The pipeline scales from synthetic test data to real experimental data:

| Aspect                  | Synthetic (Testing) | Cohort (Validation) | Real CSN (Production)   |
| ----------------------- | ------------------- | ------------------- | ----------------------- |
| Participants            | 5                   | 57                  | 57 (50 complete)        |
| Trials per participant  | 60 (1 min)          | 60 (1 min)          | 3,600 (60 min)          |
| Total trials            | 300                 | 3,420               | 180,000                 |
| Samples per participant | 30,000              | 30,000              | 1,800,000               |
| Total samples           | 150,000             | 1,710,000           | ~90,000,000             |
| Signal probability      | 1%                  | 1%                  | 1%                      |
| File size (raw data)    | ~10 MB              | ~120 MB             | ~5 GB                   |
| **Processing time**     | **8.5s**            | **1m 17s**          | **~10-15 min**          |
| **Memory usage**        | **<1 GB**           | **<2 GB**           | **<8 GB** (with polars) |
| Backend                 | dplyr               | polars              | polars                  |

**Performance**: Polars provides 6-10x speedup on aggregation; parquet compression saves 65% storage; smart dispatch automatically optimizes based on scale.

---

## Documentation

- **Function reference**: `?read_mat_data`, `?parse_validation_msgs`, `?classify_behavioral_outcomes`
- **Pipeline guide**: [`PIPELINES.md`](PIPELINES.md) - Pipeline variants explained
- **Output guide**: [`output/README.md`](output/README.md) - Directory structure and data schemas
- **Specifications**: `.specs/` directory (kept local) - Complete revival specs (PR-A, PR-B, PR-C)
- **Vignettes**: (Coming in PR-B) "From .mat to on-task"

---

## Development

### Project Structure

```
itrackvalr/
├── R/                          # Package R code (13 modules, ~3,800 lines)
│   ├── read_mat_data.R              # .mat file ingestion
│   ├── calibration.R                # Validation, offsets, zone radius, coordinate conversions (PR-B)
│   ├── behavioral.R                 # Behavioral extraction & classification
│   ├── multi_participant.R          # Multi-participant aggregation with smart dispatch (PR-B)
│   ├── multi_participant_polars.R   # Polars lazy aggregation (PR-B)
│   ├── utils_polars.R               # LazyFrame utilities (PR-B)
│   ├── resampling.R                 # Uniform grid resampling (PR-B)
│   ├── clock_hand.R                 # Hand dynamics & positioning (PR-B)
│   ├── preprocessing.R              # Distance, binarization, segmentation (PR-B)
│   ├── image_analysis.R             # Image content integration (PR-B)
│   └── export_helpers.R             # Data export system
├── tests/testthat/             # Unit tests (222 tests)
│   ├── test-behavioral.R            # 61 tests
│   ├── test-calibration.R           # 54 tests (PR-B extended)
│   ├── test-polars.R                # 39 tests (PR-B new)
│   ├── test-read_mat_data.R         # 42 tests
│   ├── test-resampling.R            # 9 tests (PR-B new)
│   ├── test-clock_hand.R            # 7 tests (PR-B new)
│   ├── test-preprocessing.R         # 7 tests (PR-B new)
│   ├── test-image_analysis.R        # 8 tests (PR-B new)
│   └── test-data-quality.R          # 16 tests (PR-B new)
├── inst/extdata/
│   ├── synthetic/              # 5 test fixtures (realistic attention)
│   ├── synthetic_cohort/       # 57-participant cohort for scale testing
│   └── synthetic_fullscale/    # 57 participants × 3600 trials (optional)
├── _targets.R                  # Complete pipeline (22 targets)
├── run_pipeline.R              # Main entry point (recommended)
├── config.yml                  # Configuration (paths, screen, clock, validation)
├── vignettes/                  # Package vignettes
│   └── from-mat-to-ontask.Rmd      # Complete walkthrough (PR-B)
├── .specs/                     # Development specifications
│   ├── ADR-001-POLARS-INTEGRATION.md
│   ├── POLARS-MIGRATION-GUIDE.md
│   └── POLARS-BENCHMARKS.md
└── matlab/                     # Original MATLAB task code (REFERENCE ONLY)
    └── task.m                       # Experimental task script
```

### Running the Pipeline

```bash
# Quick run
Rscript run_pipeline.R

# Or in R console
source("run_pipeline.R")
run_itrackvalr_pipeline()

# Clean rebuild
run_itrackvalr_pipeline(clean_start = TRUE)
```

### Adding New Data Sources

To process your own `.mat` files:

1. Update `config.yml` with your data path
2. Ensure .mat files contain `subjdata` and `Edf2Mat` structures
3. Run `targets::tar_make()`
4. Find results in `output/extracted/`

---

## Contributing

We welcome contributions! Please see our [contributing guidelines](./.github/CONTRIBUTING.md).

**Current Development** (October 2025): Working on the `refactor/2025-revival` branch:

- ✅ PR-A Complete: Data ingestion, validation, behavioral extraction, multi-participant processing
- ✅ PR-B Complete: Calibration, resampling, clock-hand dynamics, on/off-task classification, visualizations, polars optimization
- 🔄 PR-C Next: Hierarchical models, image-stratified analyses, sensitivity testing

---

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](https://github.com/sokolhessnerlab/.github/tree/main/CODE_OF_CONDUCT.md).

---

## License

Distributed under the MIT License. See [LICENSE.md](LICENSE.md) for details.

---

## Contact

- **Lab Email**: sokolhessnerlab@gmail.com
- **Issues**: [GitHub Issues](https://github.com/sokolhessnerlab/itrackvalr/issues)
- **Repository**: https://github.com/sokolhessnerlab/itrackvalr

---

## Citation

If you use `itrackvalr` in your research, please cite:

```
Dyckovsky, A., & Sokol-Hessner, P. (2025). itrackvalr: An R Interface to
  Analyze Value-Based Eye-Tracking Experiments. R package version 0.3.0.
  https://github.com/sokolhessnerlab/itrackvalr
```

See `CITATION.cff` for BibTeX and other formats (to be added).

---

## References

1. **EyeLink 1000 Plus User Manual**: https://www.hse.ru/mirror/pubs/share/560338728.pdf
2. **renv documentation**: https://rstudio.github.io/renv/
3. **targets documentation**: https://docs.ropensci.org/targets/
4. **Task source code**: [`matlab/task.m`](matlab/task.m) - Original experimental script

---

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributors-shield]: https://img.shields.io/github/contributors/sokolhessnerlab/itrackvalr?style=for-the-badge
[contributors-url]: https://github.com/sokolhessnerlab/itrackvalr/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/sokolhessnerlab/itrackvalr?style=for-the-badge
[forks-url]: https://github.com/sokolhessnerlab/itrackvalr/network/members
[stars-shield]: https://img.shields.io/github/stars/sokolhessnerlab/itrackvalr?style=for-the-badge
[stars-url]: https://github.com/sokolhessnerlab/itrackvalr/stargazers
[issues-shield]: https://img.shields.io/github/issues/sokolhessnerlab/itrackvalr?style=for-the-badge
[issues-url]: https://github.com/sokolhessnerlab/itrackvalr/issues
[license-shield]: https://img.shields.io/github/license/sokolhessnerlab/itrackvalr?style=for-the-badge
[license-url]: https://github.com/sokolhessnerlab/itrackvalr/blob/main/LICENSE.md

---

**Development Branch**: `refactor/2025-revival`  
**Last Updated**: October 1, 2025  
**Status**: ✅ PR-B Complete (Full Eye-Tracking Pipeline with Polars Optimization)  
**Tests**: 222 passing, 0 failures  
**Validated Scale**: 57 participants × 60 trials (1.71M samples, 1m 17s, <2 GB RAM)  
**Next**: PR-C (Statistical Modeling & Image-Stratified Analyses)
