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

## Batch Submission Grading

- Add a `grade-batch` CLI command that grades every submission package in a
  directory.
- Write one Markdown feedback report per student and a single combined CSV file.
- Support student IDs from directory names, a manifest CSV, or a configurable
  pattern.
- Add failure isolation so one broken submission does not stop the whole batch.
- Add summary reporting for missing submissions, environment failures, zero
  gates, and total marks.
