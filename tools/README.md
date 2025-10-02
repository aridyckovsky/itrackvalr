# Development Tools

This directory contains development and testing tools that are not part of the installed R package.

## Contents

### `python/` - Synthetic Data Generation

Python scripts for creating realistic synthetic `.mat` files for testing:

- `create_and_test_synthetic_data.py` - Main generator
- `main.py` - Entry point wrapper
- `pyproject.toml` - Python dependencies
- `uv.lock` - Locked dependency versions

See `python/README.md` for usage instructions.

**Quick start**:

```bash
cd python
uv run python create_and_test_synthetic_data.py --help
```

## Why Separate from R Package?

These tools are for **development only**:

- Generate test fixtures
- Create scale-testing datasets
- Not needed by package users
- Would bloat package distribution

**Development workflow**:

1. Use Python scripts to generate `.mat` files
2. Commit test fixtures (`inst/extdata/synthetic/`)
3. Exclude large cohorts from package (`.Rbuildignore`)
4. R package works with pre-generated fixtures

---

**Note**: Only `inst/extdata/synthetic/` (5 small test fixtures) is included in the R package.
