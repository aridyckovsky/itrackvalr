# Contributing to itrackvalr

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Quick Start

1. Fork and clone the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes following our coding standards
4. Write/update tests for your changes
5. Ensure all checks pass: `devtools::check()`
6. Commit using **conventional commits** (see below)
7. Push and create a pull request

## Conventional Commits

We use **conventional commits** for automated versioning and changelog generation. Your commit messages should follow this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Commit Types

- `feat:` - New feature (**MINOR** version bump)
- `fix:` - Bug fix (**PATCH** version bump)
- `docs:` - Documentation only changes
- `style:` - Code style changes (formatting, no logic change)
- `refactor:` - Code refactoring (no functional change)
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks, dependency updates

### Breaking Changes

For **MAJOR** version bumps, use `!` or `BREAKING CHANGE:`:

```bash
feat!: redesign preprocessing API

BREAKING CHANGE: preprocessing functions now require zone_radii parameter
```

### Examples

```bash
# Feature (0.3.0 → 0.4.0)
git commit -m "feat(polars): add LazyFrame support for large datasets"

# Bug fix (0.3.0 → 0.3.1)
git commit -m "fix(calibration): correct offset interpolation calculation"

# Documentation
git commit -m "docs: update README with polars installation instructions"

# Breaking change (0.3.0 → 1.0.0)
git commit -m "feat!: redesign calibration API

BREAKING CHANGE: apply_calibration_offsets now requires validation_df parameter"
```

## Development Workflow

We use GitHub to host code, track issues, and accept pull requests.

### Pull Request Process

1. **Fork the repo** and create your branch from `main` or `refactor/2025-revival`
2. **Generate synthetic data** (if testing locally):
   ```bash
   cd tools/python
   uv run python create_and_test_synthetic_data.py \
     --num-participants 5 \
     --output-dir ../../inst/extdata/synthetic \
     --prefix synthetic \
     --validate
   ```
3. **Make your changes** following our [coding standards](.cursor/rules/r-code-standards.mdc)
4. **Add tests** - every new function needs tests in `tests/testthat/`
5. **Update documentation** - run `roxygen2::roxygenise()` after changes
6. **Run checks locally**:
   ```r
   devtools::load_all()
   devtools::check()
   testthat::test_dir("tests/testthat")
   targets::tar_validate()
   ```
7. **Commit with conventional commits** (see above)
8. **Push and create PR** - our CI will run all checks automatically

## Any contributions you make will be under the MIT Software License

In short, when you submit code changes, your submissions are understood to be under the same [MIT License](http://choosealicense.com/licenses/mit/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report Bugs

Use GitHub's [issue tracker](https://github.com/sokolhessnerlab/itrackvalr/issues) to report bugs.

Before creating an issue:

1. Check if the issue already exists
2. Update to the latest version
3. Run `devtools::check()` to verify it's not a local issue

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can. [See stackoverflow question](http://stackoverflow.com/q/12488905/180626) that includes sample code that _anyone_ with a base R setup can run to reproduce what @briandk was seeing
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

We _love_ thorough bug reports.

## Coding Standards

We follow strict coding standards documented in [`.cursor/rules/`](.cursor/rules/):

### R Code Style

- **2 spaces** for indentation (not tabs)
- **snake_case** for variables and functions: `my_variable`, `compute_distance()`
- **Roxygen2** documentation for all exported functions
- **Native pipe** `|>` preferred over `%>%`
- **Explicit namespacing**: `dplyr::mutate()` rather than importing

See [r-code-standards.mdc](.cursor/rules/r-code-standards.mdc) for complete guidelines.

### Function Structure

```r
my_function <- function(input_df, param1 = default) {
  # 1. INPUT VALIDATION
  required_cols <- c("id", "t", "x_px")
  # ... validation code ...

  # 2. MAIN LOGIC
  result <- input_df |>
    dplyr::filter(!is.na(x_px)) |>
    dplyr::mutate(new_col = transform(x_px))

  # 3. OUTPUT VALIDATION
  if (nrow(result) == 0) {
    cli::cli_warn("Empty result")
  }

  # 4. RETURN
  return(result)
}
```

### Documentation

Every exported function needs:

- One-line title
- `@description` explaining purpose
- `@param` for each parameter
- `@return` describing output structure
- `@examples` showing usage
- `@export` tag

### Testing

- Test files mirror R files: `R/behavioral.R` → `tests/testthat/test-behavioral.R`
- Test happy path AND edge cases
- Use synthetic fixtures from `inst/extdata/synthetic/`
- Aim for >80% code coverage

See [testing-standards.mdc](.cursor/rules/testing-standards.mdc) for details.

## License

By contributing, you agree that your contributions will be licensed under its MIT License.

## References

This document was adapted from the open-source contribution guidelines for [Facebook's Draft](https://github.com/facebook/draft-js/blob/a9316a723f9e918afde44dea68b5f9f39b7d9b00/CONTRIBUTING.md)
