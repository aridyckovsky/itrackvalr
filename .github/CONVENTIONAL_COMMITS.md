# Conventional Commits Guide for itrackvalr

## Quick Reference

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

## Types

| Type       | Purpose                 | Version Impact        | Example                                 |
| ---------- | ----------------------- | --------------------- | --------------------------------------- |
| `feat`     | New feature             | MINOR (0.3.0 → 0.4.0) | `feat(polars): add LazyFrame support`   |
| `fix`      | Bug fix                 | PATCH (0.3.0 → 0.3.1) | `fix(calibration): correct offset calc` |
| `docs`     | Documentation           | None                  | `docs: update README installation`      |
| `style`    | Formatting, whitespace  | None                  | `style: format with styler`             |
| `refactor` | Code restructuring      | None                  | `refactor: extract validation helpers`  |
| `test`     | Add/update tests        | None                  | `test: add edge cases for resampling`   |
| `chore`    | Maintenance             | None                  | `chore(deps): update tidypolars`        |
| `perf`     | Performance improvement | None                  | `perf: optimize distance calculation`   |
| `ci`       | CI/workflow changes     | None                  | `ci: add synthetic data generation`     |

## Breaking Changes

For **MAJOR** version bumps (0.3.0 → 1.0.0):

### Option 1: Use `!` after type

```bash
git commit -m "feat!: redesign preprocessing API"
```

### Option 2: Add `BREAKING CHANGE:` footer

```bash
git commit -m "feat(preprocessing): redesign binarization API

BREAKING CHANGE: binarize_on_task now requires zone_radii parameter.
Update existing code:
  Old: binarize_on_task(samples)
  New: binarize_on_task(samples, zone_radii)
"
```

## Scopes (Optional)

Common scopes for itrackvalr:

- `polars` - Polars integration code
- `calibration` - Calibration and validation
- `behavioral` - Behavioral data processing
- `preprocessing` - Preprocessing pipeline
- `pipeline` - targets pipeline
- `export` - Data export functionality
- `tests` - Test infrastructure
- `docs` - Documentation
- `deps` - Dependencies
- `ci` - CI/CD workflows

## Examples by Scenario

### Adding a New Feature

```bash
# Simple feature
git commit -m "feat: add support for 1000Hz sampling rate"

# Feature with scope
git commit -m "feat(resampling): add gap detection and interpolation"

# Feature with details
git commit -m "feat(polars): add smart dispatch for scale-aware processing

Automatically selects dplyr for ≤10 participants and polars for >10.
Provides 10-15x speedup on large datasets (57 participants).
"
```

### Fixing a Bug

```bash
# Simple fix
git commit -m "fix: handle NA values in pupil area"

# Fix with scope and issue reference
git commit -m "fix(calibration): prevent division by zero in offset calculation

Closes #123
"

# Critical fix
git commit -m "fix(behavioral): correct hit classification logic

Previously misclassified hits when response_time was exactly 8000ms.
Now uses inclusive comparison (<=) per task.m specification.
"
```

### Documentation Updates

```bash
# README update
git commit -m "docs: add polars performance benchmarks to README"

# Vignette
git commit -m "docs(vignette): add from-mat-to-ontask walkthrough"

# Code comments
git commit -m "docs(calibration): add task.m line references to functions"
```

### Refactoring

```bash
# Extract helper
git commit -m "refactor(behavioral): extract outcome classification helpers"

# Reorganize
git commit -m "refactor: split multi_participant.R into dplyr and polars modules"
```

### Tests

```bash
# Add tests
git commit -m "test(polars): add LazyFrame compatibility tests"

# Fix flaky test
git commit -m "test(calibration): make validation test deterministic"

# Increase coverage
git commit -m "test: add edge cases for empty datasets"
```

### Maintenance

```bash
# Update dependencies
git commit -m "chore(deps): update renv lockfile with tidypolars 0.11.0"

# CI changes
git commit -m "ci: add workflow for synthetic data generation"

# Tooling
git commit -m "chore: add pre-commit hook for conventional commits"
```

## Multi-Paragraph Commits

For complex changes:

```bash
git commit -m "feat(preprocessing): implement trial segmentation

Segments binarized samples into 1-second trials based on image onset/offset
events. Handles edge cases:
- Missing events (skips trial)
- Overlapping trials (uses first onset)
- Trials extending beyond session end (truncates)

Adds new columns:
- trial: trial number
- t_trial_ms: time within trial (0-1000ms)
- trial_start_ms: absolute trial start time

Related to PR-B preprocessing pipeline completion.
"
```

## Commit Body and Footer

### Body Guidelines

- Explain WHAT changed and WHY (code shows HOW)
- Reference task.m line numbers if replicating MATLAB logic
- Describe edge cases handled
- Note performance implications
- Link to related issues/PRs

### Footer Types

```bash
# Issue references
Closes #42
Fixes #123
Resolves #456

# Breaking changes
BREAKING CHANGE: API redesigned, see migration guide

# Co-authors
Co-authored-by: Name <email@example.com>

# Related work
Related-to: #789
See-also: PR#45
```

## Automated Release Process

When you push to `main` with conventional commits:

1. **Release workflow** analyzes commits since last tag
2. **Determines version bump**:
   - BREAKING CHANGE or `!` → MAJOR
   - `feat:` → MINOR
   - `fix:` → PATCH
   - Other → No release
3. **Updates DESCRIPTION** version field
4. **Regenerates docs** with roxygen2
5. **Creates NEWS.md** with categorized changelog
6. **Commits and pushes** with `[skip ci]`
7. **Creates GitHub release** with tag (e.g., v0.4.0)
8. **Builds package** and attaches .tar.gz

### Changelog Format

Generated NEWS.md will include:

```markdown
# itrackvalr 0.4.0 (2025-10-15)

## ⚠️ BREAKING CHANGES

- feat!: redesign preprocessing API (abc123)

## ✨ Features

- feat(polars): add LazyFrame support (def456)
- feat(export): add parquet export format (ghi789)

## 🐛 Bug Fixes

- fix(calibration): correct offset interpolation (jkl012)

## 📦 Other Changes

- docs: update README (mno345)
- test: increase coverage to 85% (pqr678)
```

## Skip Release

To commit to `main` without triggering a release:

```bash
git commit -m "docs: update README [skip ci]"
git commit -m "chore: update .cursor rules [ci skip]"
```

Use for:

- Documentation-only changes
- Non-code updates (rules, configs)
- README updates
- Comment changes

## Check Commits Before Pushing

Run the validation script:

```bash
# Check last 10 commits
.github/scripts/check-conventional-commits.sh

# Check specific number
.github/scripts/check-conventional-commits.sh 20
```

Or manually inspect:

```bash
# View recent commits
git log -10 --oneline

# Check if commits match pattern
git log -10 --pretty=format:"%s" | grep -E "^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?!?: "
```

## Git Hooks (Optional)

Add a commit-msg hook to validate locally:

```bash
# .git/hooks/commit-msg
#!/bin/bash
commit_msg=$(cat "$1")

# Allow merge commits
if echo "$commit_msg" | grep -qE "^Merge"; then
  exit 0
fi

# Allow [skip ci] commits
if echo "$commit_msg" | grep -qE "\[(skip ci|ci skip)\]"; then
  exit 0
fi

# Check conventional format
if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\(.+\))?!?: "; then
  echo "❌ Commit message must follow conventional commits format"
  echo ""
  echo "Format: <type>(<scope>): <subject>"
  echo ""
  echo "Valid types: feat, fix, docs, style, refactor, test, chore, build, ci, perf, revert"
  echo ""
  echo "Examples:"
  echo "  feat(polars): add LazyFrame support"
  echo "  fix(calibration): correct offset calculation"
  echo "  docs: update README"
  echo ""
  exit 1
fi
```

Make it executable:

```bash
chmod +x .git/hooks/commit-msg
```

## Resources

- **Conventional Commits Spec**: https://www.conventionalcommits.org/
- **Semantic Versioning**: https://semver.org/
- **GitHub Flow**: https://guides.github.com/introduction/flow/
- **Our Workflows**: [.github/workflows/README.md](.github/workflows/README.md)
- **Release Workflow**: [.github/workflows/release.yml](.github/workflows/release.yml)

---

**Questions?** See [CONTRIBUTING.md](CONTRIBUTING.md) or ask in discussions.
