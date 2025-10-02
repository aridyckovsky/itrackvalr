# GitHub Actions Workflows for itrackvalr

Streamlined CI/CD workflows using **synthetic test data** for reproducible, fast testing.

## Workflow Structure (4 Workflows Total)

```
generate-synthetic-data.yml (reusable)
         ↓
    ┌────┴─────┬──────────┐
    ↓          ↓          ↓
R-CMD-check  pkgdown  release
(main CI)    (docs)   (main only)
```

---

## Core Workflows

### 1. `generate-synthetic-data.yml` (Reusable)

**Purpose**: Generate synthetic .mat test files using Python

**Type**: Reusable workflow (called by other workflows)

**What it does**:

1. Sets up Python 3.13 with uv package manager
2. Installs dependencies from `tools/python/pyproject.toml`
3. Runs `create_and_test_synthetic_data.py`:
   - Creates 5 synthetic participants
   - 60 trials each (~1 minute simulated session)
   - Realistic attention patterns and calibration
   - Validates file structure
4. Uploads `synthetic-data` artifact (7-day retention)

**Manual trigger**: Available via workflow_dispatch

**Usage in other workflows**:

```yaml
jobs:
  generate-data:
    uses: ./.github/workflows/generate-synthetic-data.yml

  my-job:
    needs: generate-data
    steps:
      - name: Download synthetic data
        uses: actions/download-artifact@v4
        with:
          name: synthetic-data
          path: inst/extdata/synthetic/
```

---

### 2. `R-CMD-check.yml` ⭐ **Main CI Workflow**

**Purpose**: Comprehensive R package validation (tests, checks, pipeline)

**Triggers**:

- Push to `main` or `refactor/2025-revival`
- Pull requests to these branches

**Jobs**:

#### **Job 1: Generate Data**

Uses `generate-synthetic-data.yml` to create test fixtures

#### **Job 2: Package Check (Matrix)**

Runs on multiple platforms:

- Ubuntu (R-release, R-devel)
- macOS (R-release)
- Windows (R-release)

**Each platform**:

1. ✅ Downloads synthetic data
2. ✅ Validates DESCRIPTION and NAMESPACE
3. ✅ Validates targets pipeline structure
4. ✅ Runs targets pipeline (Ubuntu release only - fastest)
5. ✅ Runs `R CMD check` (comprehensive package validation)
6. ✅ Uploads check results and snapshots

#### **Job 3: Test Coverage** (Ubuntu only, push only)

1. Runs `covr::package_coverage()`
2. Reports coverage percentage
3. Uploads to Codecov (requires `CODECOV_TOKEN`)
4. Warns if coverage <70%

#### **Job 4: Summary**

Confirms all checks passed

**This replaces**: `ci.yml`, `test-coverage.yml`, `targets-pipeline.yml`

---

### 3. `pkgdown.yml` (Documentation)

**Purpose**: Build and deploy package website

**Triggers**:

- Push to main/refactor branches
- Releases
- Manual dispatch

**What it does**:

1. Generates synthetic data
2. Builds pkgdown documentation site
3. Deploys to GitHub Pages (`gh-pages` branch)

**Deployed to**: https://sokolhessnerlab.github.io/itrackvalr/

---

### 4. `release.yml` (Automated Releases)

**Purpose**: Automated versioning using conventional commits

**Trigger**: Push to `main` branch ONLY

**Conventional Commits → Version Bumps**:

- `BREAKING CHANGE:` or `type!:` → **MAJOR** (0.3.0 → 1.0.0)
- `feat:` → **MINOR** (0.3.0 → 0.4.0)
- `fix:` → **PATCH** (0.3.0 → 0.3.1)
- Other types (`docs`, `chore`, etc.) → No release

**Process**:

1. Parses commits since last tag
2. Determines version bump from commit types
3. Updates DESCRIPTION version
4. Regenerates documentation with roxygen2
5. Creates/updates NEWS.md changelog
6. Commits changes with `[skip ci]`
7. Creates GitHub release with tag
8. Builds and attaches .tar.gz package

**Example commits**:

```bash
# MINOR: 0.3.0 → 0.4.0
git commit -m "feat(polars): add LazyFrame support for large datasets"

# PATCH: 0.3.0 → 0.3.1
git commit -m "fix(calibration): correct offset interpolation"

# MAJOR: 0.3.0 → 1.0.0
git commit -m "feat!: redesign preprocessing API

BREAKING CHANGE: binarize_on_task requires zone_radii parameter"
```

---

## Workflow Dependencies

### Artifact Flow

```
generate-synthetic-data.yml
    ↓ (produces artifact: synthetic-data)
    ├→ R-CMD-check.yml (downloads artifact)
    ├→ pkgdown.yml (downloads artifact)
    └→ release.yml (implicit - package already validated)
```

### Job Dependencies (within R-CMD-check.yml)

```
generate-data (creates fixtures)
    ↓
    ├→ check (matrix: Ubuntu/macOS/Windows)
    └→ coverage (Ubuntu only)
         ↓
    check-success (summary)
```

---

## What Each Workflow Tests

### R-CMD-check.yml (Main CI)

- ✅ Package structure (DESCRIPTION, NAMESPACE)
- ✅ Documentation sync (roxygen2)
- ✅ Targets pipeline validation
- ✅ Pipeline execution (end-to-end)
- ✅ Unit tests (222 tests)
- ✅ R CMD check (CRAN compliance)
- ✅ Test coverage >70%
- ✅ Cross-platform compatibility

### pkgdown.yml

- ✅ Documentation builds without errors
- ✅ Examples run successfully
- ✅ Site deployment works

### release.yml

- ✅ Conventional commit parsing
- ✅ Version bumping logic
- ✅ Changelog generation
- ✅ Package build
- ✅ GitHub release creation

---

## Running Workflows Locally

### Full CI Simulation

```bash
# 1. Generate synthetic data (like workflow)
cd tools/python
uv run python create_and_test_synthetic_data.py \
  --num-participants 5 \
  --output-dir ../../inst/extdata/synthetic \
  --prefix synthetic \
  --validate

# 2. Validate package (like workflow)
cd ../..
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'targets::tar_validate()'
Rscript -e 'targets::tar_manifest()'

# 3. Run pipeline (like workflow)
Rscript -e 'source("run_pipeline.R"); run_itrackvalr_pipeline()'

# 4. Run R CMD check (like workflow)
Rscript -e 'devtools::check()'

# 5. Check coverage (like workflow)
Rscript -e 'covr::package_coverage()'
```

### Quick Checks

```r
# In R console
devtools::load_all()           # Load package
devtools::check()              # R CMD check
testthat::test_dir("tests/testthat")  # Run tests
targets::tar_validate()        # Validate pipeline
```

---

## Required Secrets

Configure in repository Settings → Secrets and variables → Actions:

| Secret          | Used By                    | Required?        | How to Get                 |
| --------------- | -------------------------- | ---------------- | -------------------------- |
| `GITHUB_TOKEN`  | All workflows              | ✅ Auto-provided | N/A - automatic            |
| `CODECOV_TOKEN` | R-CMD-check (coverage job) | Optional         | codecov.io → Repo Settings |

**Note**: Workflows will run without `CODECOV_TOKEN`, but coverage won't be reported to Codecov.

---

## Status Badges

Add to README.md:

```markdown
[![R-CMD-check](https://github.com/sokolhessnerlab/itrackvalr/workflows/R-CMD-check/badge.svg)](https://github.com/sokolhessnerlab/itrackvalr/actions)
[![Codecov](https://codecov.io/gh/sokolhessnerlab/itrackvalr/branch/main/graph/badge.svg)](https://app.codecov.io/gh/sokolhessnerlab/itrackvalr)
[![pkgdown](https://github.com/sokolhessnerlab/itrackvalr/workflows/pkgdown/badge.svg)](https://sokolhessnerlab.github.io/itrackvalr/)
```

---

## Conventional Commits

See [CONVENTIONAL_COMMITS.md](../CONVENTIONAL_COMMITS.md) for complete guide.

### Quick Reference

```bash
# Feature → Minor version bump
git commit -m "feat(polars): add LazyFrame support"

# Fix → Patch version bump
git commit -m "fix(calibration): correct offset calculation"

# Breaking change → Major version bump
git commit -m "feat!: redesign preprocessing API

BREAKING CHANGE: preprocessing functions now require zone_radii parameter"

# No release (docs, chore, test, style, refactor)
git commit -m "docs: update README with installation steps"
```

---

## Debugging Failed Workflows

### Common Issues

**1. Synthetic data generation fails**

```bash
# Check locally
cd tools/python
uv run python create_and_test_synthetic_data.py --validate
```

**2. renv restore fails**

```r
# Update lockfile
renv::snapshot()
git add renv.lock
git commit -m "chore(deps): update renv lockfile"
```

**3. NAMESPACE out of sync**

```r
# Regenerate
roxygen2::roxygenise()
git add NAMESPACE man/
git commit -m "docs: update generated documentation"
```

**4. Pipeline validation fails**

```r
# Check locally
targets::tar_validate()
targets::tar_manifest()
```

**5. Tests fail**

```r
# Run locally with same data
testthat::test_dir("tests/testthat")
```

### Download Artifacts for Inspection

1. Go to failed workflow run
2. Scroll to "Artifacts" section
3. Download `check-results` or `pipeline-outputs`

---

## Workflow Maintenance

### Update Action Versions

Periodically check for updates:

```yaml
- uses: actions/checkout@v4 # Latest: v4
- uses: r-lib/actions/setup-r@v2 # Latest: v2
- uses: r-lib/actions/setup-renv@v2 # Latest: v2
```

### Add New R Version to Matrix

Edit `R-CMD-check.yml`:

```yaml
matrix:
  config:
    - { os: ubuntu-latest, r: "release" }
    - { os: ubuntu-latest, r: "devel" }
    - { os: ubuntu-latest, r: "oldrel-1" } # Add new versions here
```

### Update Python Version

Edit `generate-synthetic-data.yml`:

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: "3.13" # Update as needed
```

---

## Performance Optimization

### Current Optimizations

1. **Reusable workflow** for data generation (run once, share artifact)
2. **Matrix parallelization** (4 platforms run simultaneously)
3. **Conditional jobs** (coverage only on Ubuntu, pipeline only on one platform)
4. **Binary package installs** (`use-public-rspm: true`)
5. **renv caching** (via `r-lib/actions/setup-renv`)
6. **Minimal artifact retention** (7 days)

### Execution Time Estimates

| Workflow                   | Duration  | Parallel Jobs |
| -------------------------- | --------- | ------------- |
| generate-synthetic-data    | ~2 min    | 1             |
| R-CMD-check (per platform) | ~8-12 min | 4 (matrix)    |
| pkgdown                    | ~5 min    | 1             |
| release                    | ~3 min    | 1             |

**Total PR check time**: ~10-15 minutes (parallelized)

---

## Branch Protection Rules

Recommended required status checks:

### For `main` branch:

- ✅ `check-success` (from R-CMD-check.yml)
- ✅ `pkgdown` (optional but recommended)

### For `refactor/2025-revival` branch:

- ✅ `check-success` (from R-CMD-check.yml)

**Note**: Don't require individual matrix jobs, just the summary `check-success` job.

---

## Workflow Files Summary

| File                          | Purpose                      | Triggers                 | Key Jobs                                   |
| ----------------------------- | ---------------------------- | ------------------------ | ------------------------------------------ |
| `generate-synthetic-data.yml` | Generate test data           | Called by others, manual | Python data generation                     |
| `R-CMD-check.yml`             | **Main CI** - all validation | Push, PR                 | Data → Check (matrix) → Coverage → Summary |
| `pkgdown.yml`                 | Documentation site           | Push, release, manual    | Data → Build site → Deploy                 |
| `release.yml`                 | Automated releases           | Push to main only        | Parse commits → Bump version → Release     |

**Total: 4 workflows** (down from 7+) with **zero duplication**

---

## Quick Start for Contributors

### Running Checks Locally

```r
# Before pushing, run locally:
devtools::load_all()
devtools::check()
testthat::test_dir("tests/testthat")
targets::tar_validate()
```

### Commit Format

Use conventional commits for automatic versioning:

```bash
feat(scope): add new feature      # Minor bump
fix(scope): fix bug               # Patch bump
feat!: breaking change            # Major bump
docs: update docs                 # No release
```

See [CONVENTIONAL_COMMITS.md](../CONVENTIONAL_COMMITS.md) for details.

---

## Resources

- **Conventional Commits**: [CONVENTIONAL_COMMITS.md](../CONVENTIONAL_COMMITS.md)
- **Contributing Guide**: [CONTRIBUTING.md](../CONTRIBUTING.md)
- **Cursor Rules**: [../.cursor/rules/github-workflows.mdc](../.cursor/rules/github-workflows.mdc)
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **r-lib/actions**: https://github.com/r-lib/actions

---

**Last Updated**: October 2, 2025  
**Workflows**: 4 (streamlined from 7)  
**CI Time**: ~10-15 min (parallelized)  
**Maintained By**: Project contributors
