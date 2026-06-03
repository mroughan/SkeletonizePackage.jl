# TODO

## Code Property Checks

- Replace simple string and regular-expression checks with JuliaSyntax-backed
  parsing where it makes requirements clearer and less heuristic.
- Improve import and call detection so comments and strings do not count as
  source-level behaviour unless a teacher explicitly asks for textual checks.
- Add clearer diagnostic messages for each property check explaining what was
  found and where.
- Consider project-wide property scopes, function-scoped property scopes, and
  block-scoped property scopes as separate concepts.

## GitHub Actions Integration

- Publish a sample `.github/workflows/grade.yml` that runs `grade_submission` for
  each subdirectory in a `submissions/` folder and uploads a combined CSV and HTML
  reports as workflow artifacts.
- Document the workflow template in README.md.
- Support configuring reference path, timeout, and CSV format via workflow inputs.

## Incremental Grading

- Cache the `GradeResult` per student (keyed by content hash of the submission and
  the rubric).
- Re-grade only when the submission or rubric changes since the last run.
- Add a `--cache-dir PATH` option to the CLI batch command.

## Pluto Notebook Support

- Add a transformer for `.jl` Pluto notebooks (detect the `# ╔═╡` cell markers).
- Strip annotated cells rather than annotated lines, matching Pluto's cell model.
- Add validation rules specific to Pluto package structure.

## Partial Credit

- Extend `@marks` to accept `partial=true` and a `partial_scorer` function.
- Allow reference tests to award fractional marks when a subset of generated inputs match.
- Store `partial_awarded::Float64` alongside `awarded::Int` in `CriterionResult`.

## Batch Submission Grading

- Add a `grade-batch` CLI command that grades every submission package in a
  directory.
- Write one Markdown feedback report per student and a single combined CSV file.
- Support student IDs from directory names, a manifest CSV, or a configurable
  pattern.
- Add failure isolation so one broken submission does not stop the whole batch.
- Add summary reporting for missing submissions, environment failures, zero
  gates, and total marks.
