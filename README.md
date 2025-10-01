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
- 🔄 **Coming in PR-B**: Calibration application, resampling, clock-hand dynamics, on/off-task binarization
- 🔄 **Coming in PR-C**: Hierarchical models, model-free analyses, sensitivity testing

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

The dependencies are tracked by version in the `renv.lock` file (138 packages for R 4.5.1). If during development you install a package that the project will depend on to run properly, please use `renv::snapshot()` to update the lock file.

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

```r
# Load package for development
devtools::load_all()

# Run tests (133 tests)
testthat::test_dir("tests/testthat")

# Run the pipeline (multi-participant by default)
targets::tar_make()

# Or use the pipeline runner
source("run_pipeline.R")
run_itrackvalr_pipeline()
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

**Future columns (PR-B)**: `x_px_adj`, `y_px_adj` (after calibration), `x_px_std`, `y_px_std` (resampled), `dist_to_tip_px`, `on_task`

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

### Default: Multi-Participant Processing

Process all participants in your data directory:

```r
library(targets)

# Configure data path in config.yml first!
# Edit config.yml:
#   path:
#     data: "/path/to/your/mat/files"

# Run pipeline
tar_make()

# View progress
tar_progress()

# Access aggregated results (all participants combined)
all_samples <- tar_read(all_samples)       # All gaze samples
all_behavioral <- tar_read(all_behavioral) # All trials
all_metadata <- tar_read(all_metadata)     # Participant metadata

cohort_behav_summary <- tar_read(cohort_behavioral_summary)
# Per-participant: n_hits, hit_rate, d_prime, mean_rt, etc.

cohort_summary <- tar_read(cohort_summary)
# Overall: n_participants, mean_hit_rate, mean_d_prime, etc.
```

### Exported Data Files

After running the pipeline, find exported data in `output/extracted/`:

**Aggregated datasets** (all participants combined):

- `ALL_samples.parquet` - All gaze samples (Parquet for efficiency)
- `ALL_events.csv` + `.parquet` - All events
- `ALL_behavioral.csv` + `.parquet` - All trials with outcomes
- `ALL_metadata.csv` - Participant information
- `cohort_behavioral_summary.csv` - Per-participant statistics
- `cohort_validation_summary.csv` - Validation analysis

**Manifest**:

- `MANIFEST.csv` - Complete catalog of exported files with sizes

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
# Run all tests (133 tests)
testthat::test_dir("tests/testthat")

# Run specific test suite
testthat::test_file("tests/testthat/test-behavioral.R")   # 61 tests
testthat::test_file("tests/testthat/test-calibration.R")  # 30 tests
testthat::test_file("tests/testthat/test-read_mat_data.R") # 42 tests
```

**Current coverage**:

- ✅ 133 tests passing
- ✅ 0 failures, 0 warnings
- ✅ Covers: .mat ingestion, validation parsing, behavioral extraction, outcome classification, edge cases

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

### PR-B: Calibration & Preprocessing 🔄 (Next)

**Input**: Extracted data from PR-A

**Will implement**:

1. Apply calibration offsets (interpolated across session)
2. Resample to standard frequency
3. Compute clock-hand tip positions at each timestamp
4. Calculate distance from gaze to clock-hand tip
5. Binarize into on-task/off-task using zone of uncertainty
6. Segment data into image-presentation trials
7. Model-free analyses (p(on-task) timecourses)

**Output**: `output/calibrated/`, `output/preprocessed/`, `output/analysis/`

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

| Aspect                  | Synthetic (Testing) | Real CSN (Production) |
| ----------------------- | ------------------- | --------------------- |
| Participants            | 5                   | 57 (50 complete)      |
| Trials per participant  | 60 (1 min)          | 3,600 (60 min)        |
| Total trials            | 300                 | ~180,000              |
| Samples per participant | 30,000              | 1,800,000             |
| Total samples           | 150,000             | ~90,000,000           |
| Signal probability      | 1%                  | 1%                    |
| File size (ALL_samples) | 4.6 MB              | ~500 MB               |
| Processing time         | <2 sec              | ~5-10 min             |

**Performance**: Parquet format provides 65% compression; parallel processing available via `targets` + `crew`/`future`.

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
├── R/                      # Package R code (5 modules, 1,294 lines)
│   ├── read_mat_data.R          # .mat file ingestion
│   ├── calibration.R            # Validation parsing & analysis
│   ├── behavioral.R             # Behavioral extraction & classification
│   ├── export_helpers.R         # Data export system
│   └── multi_participant.R      # Multi-participant processing
├── tests/testthat/         # Unit tests (133 tests)
├── inst/extdata/synthetic/ # Synthetic .mat fixtures (5 files)
├── _targets.R              # Multi-participant pipeline (default)
├── _targets_single.R       # Single-participant pipeline
├── config.yml              # Configuration (paths, screen, clock params)
├── run_pipeline.R          # Pipeline runner script
└── matlab/                 # Original MATLAB task code (DO NOT MODIFY)
    └── task.m              # Experimental task script
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
- 🔄 PR-B Next: Calibration application, resampling, clock-hand dynamics, binarization
- 🔄 PR-C Future: Hierarchical models, model-free analyses, sensitivity testing

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
**Status**: ✅ PR-A Complete (Data Ingestion + Multi-Participant Processing)  
**Next**: PR-B (Calibration, Resampling, Binarization)
