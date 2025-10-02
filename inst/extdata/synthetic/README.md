# Synthetic Test Data

This directory contains 5 synthetic participants for testing the itrackvalr pipeline.

## Generation

Created with `tools/python/create_and_test_synthetic_data.py` using realistic attention model:

```bash
cd tools/python
uv run python create_and_test_synthetic_data.py \
  --num-participants 5 \
  --output-dir ../../inst/extdata/synthetic \
  --prefix synthetic
```

## Characteristics

**Gaze behavior** (realistic attention model):

- 80% on-task (tracking clock hand) after 300ms
- 60% looking at image in first 300ms of trial
- 15 px measurement noise (realistic for EyeLink remote mode)
- 0.2% blink rate

**Calibration** (participant-specific):

- Pre-task avg error: 0.4-1.2° (varies by participant)
- Post-task: Slight drift (±20%)
- Offsets: -20 to +20 px (varies by participant)

**Expected pipeline results**:

- On-task rate: 50-65% (attention + noise + zone radius variation)
- Zone radius: 20-40 px (depends on participant calibration quality)
- Trial duration: 1000ms
- Samples per trial: ~500 (500 Hz)

## Files

- `synthetic_01.mat` through `synthetic_05.mat`
- Each: 60 trials, 30,000 samples, ~130 events
- Structure identical to real CSN .mat files

## Differences from Real Data

✅ **Same**: File structure, field names, data types, trial timing  
✅ **Same**: Signal probability (1%), monocular right eye, calibration messages  
❌ **Different**: Shorter (60 trials vs 3,600), simplified clock hand dynamics  
❌ **Different**: Synthetic gaze model (not actual human attention)

For full-scale testing, see `inst/extdata/synthetic_cohort/` (57 participants).
