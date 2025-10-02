# itrackvalr Pipeline Variants

This project includes multiple pipeline configurations for different use cases.

---

## Default: Multi-Participant Pipeline (`_targets.R`)

**Use this for**: Processing all participants and creating cohort-level datasets

**Processes**:

- All `.mat` files in `inst/extdata/synthetic/` (or configured data directory)
- Creates per-participant datasets (optional, if export targets added)
- Creates **aggregated datasets** combining all participants
- Generates cohort-level summaries

**Run**:

```r
targets::tar_make()
# Or
Rscript run_pipeline.R
```

**Output**:

```
output/extracted/
  ├── ALL_samples.parquet          # 150,000 samples (5 participants × 30k)
  ├── ALL_events.csv/.parquet      # 654 events (all participants)
  ├── ALL_behavioral.csv/.parquet  # 300 trials (all participants)
  ├── ALL_metadata.csv             # 5 participant metadata rows
  ├── cohort_behavioral_summary.csv   # Per-participant statistics
  └── cohort_validation_summary.csv   # Validation analysis
```

**Use Case**:

- Multi-participant studies (CSN has 57 participants)
- Cohort-level analyses
- Group comparisons
- Population statistics

---

## Alternative: Single-Participant Pipeline (`_targets_single.R`)

**Use this for**: Testing, debugging, or processing one participant at a time

**Processes**:

- Single `.mat` file (e.g., `synthetic_01.mat`)
- All processing steps for that participant
- Individual exports

**Run**:

```r
targets::tar_make(script = "_targets_single.R")
```

**Output**:

```
output/extracted/
  ├── SYN01_samples.csv/.parquet
  ├── SYN01_events.csv/.parquet
  ├── SYN01_behavioral_trials.csv/.parquet
  ├── SYN01_behavioral_summary.csv
  └── validation summaries
```

**Use Case**:

- Development and debugging
- Quick iterations
- Single-participant investigations

---

## Reference: Original Pipeline (`_targets.R.old`)

The original pipeline before the 2025 revival. Kept for reference.

---

## Pipeline Structure Comparison

### Multi-Participant (Default)

```
mat_files → all_participant_data → {
  all_samples (aggregated)
  all_events (aggregated)
  all_behavioral (aggregated)
  all_validation (aggregated)
  all_metadata
} → cohort summaries → exports
```

**Targets**: ~13 (scales with number of participants)
**Output**: Cohort-level aggregated datasets

### Single-Participant

```
synthetic_file → mat_data → {
  samples_raw
  events_raw
  behavioral_trials
  metadata
} → summaries → exports
```

**Targets**: 17
**Output**: Single-participant datasets

---

## Switching Between Pipelines

```r
# Use multi-participant (default)
targets::tar_make()

# Use single-participant
targets::tar_make(script = "_targets_single.R")

# Clean and rebuild
targets::tar_destroy()
targets::tar_make()
```

---

## Configuration

Edit `config.yml` to specify:

- Data directory paths
- Screen parameters (width, height, viewing distance)
- Clock parameters (diameter, hand length, increment)
- Validation settings (response window, zone strategy)

For real CSN data:

```yaml
default:
  path:
    data: "/Volumes/shlab/Projects/CSN/data"
  participants:
    total: 57
    incomplete: 7
```

---

## Recommendations

**For Development**: Use `_targets_single.R` for fast iterations

**For Analysis**: Use `_targets.R` (multi-participant) to process entire cohort

**For CI**: Use multi-participant pipeline on synthetic data (5 participants, fast)

**For Production**: Use multi-participant pipeline on real data (57 participants)

---

**Last Updated**: October 1, 2025  
**Current Default**: Multi-participant pipeline
