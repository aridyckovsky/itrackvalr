# Python Tools for itrackvalr

This directory contains Python scripts for generating synthetic test data.

## Scripts

### `create_and_test_synthetic_data.py`

Generates realistic synthetic `.mat` files that match the CSN study structure.

**Features**:

- Attention-based gaze model (80% tracking clock, 60% on images initially)
- Participant-specific calibration (varied errors and offsets)
- Correct clock positioning (LEFT/RIGHT based on lr)
- Guaranteed minimum signal count for testing
- Full-scale option (3600 trials like real CSN)

**Usage**:

```bash
# Test fixtures (5 participants, 60 trials, fast)
# (From root)
uv run python tools/python/create_and_test_synthetic_data.py \
  --num-participants 5 \
  --output-dir inst/extdata/synthetic \
  --prefix synthetic

# Cohort testing (57 participants, 60 trials)
# (From root)
uv run python tools/python/create_and_test_synthetic_data.py \
  --num-participants 57 \
  --output-dir inst/extdata/synthetic_cohort \
  --prefix CSN

# Full scale (57 participants, 3600 trials)
# (From root)
uv run python tools/python/create_and_test_synthetic_data.py \
  --num-participants 57 \
  --output-dir inst/extdata/synthetic_fullscale \
  --prefix CSN \
  --full-scale

# With validation
uv run python tools/python/create_and_test_synthetic_data.py \
  --num-participants 5 \
  --output-dir inst/extdata/synthetic \
  --prefix synthetic \
  --validate
```

**Requirements**:

- Python 3.11+
- numpy
- scipy

Managed via `uv` (see `pyproject.toml`)

## Installation

```bash
cd tools/python

# Using uv (recommended)
uv sync

# Or using pip
pip install numpy scipy
```

## Output

Generates `.mat` files compatible with R.matlab::readMat() containing:

- `subjdata`: Behavioral data (trials, responses, signals)
- `Edf2Mat`: Eye-tracking data (samples, events, recordings)

See `../../inst/extdata/synthetic/README.md` for data characteristics.

---

**Note**: These are development tools, not part of the installed R package.
