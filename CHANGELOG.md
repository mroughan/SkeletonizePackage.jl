# Changelog

All notable changes to `SkeletonizePackage.jl` are recorded here.

This project follows the spirit of [Keep a Changelog](https://keepachangelog.com/)
and uses semantic versioning once releases begin.

## Unreleased

### Fixed (reliability refinements — session 3)

- `_criterion_results`: reference-test criterion items now match by function name as well
  as visibility, fixing a logic bug where multiple `@reference_test` entries in the same
  annotation block were conflated into every reference-test criterion.
- `_json_string`: full RFC 8259 control-character escaping (U+0000–U+001F) added; previously
  only `\n`, `\r`, `\t` were escaped, producing invalid JSON when stderr contained other
  control characters.
- `_build_html_report`: unclosed fenced code block (` ``` ` with no closing fence) no
  longer leaves the rest of the HTML document inside a `<pre>` tag.
- `_fmt_inline`: an odd number of backticks in a description (unmatched single backtick)
  now falls back to plain HTML-escaped text rather than wrapping the trailing fragment
  in a `<code>` span.
- `grade_submission`: `csv_format` is now validated at the top of the function, before any
  subprocess grading runs, so an invalid format symbol fails fast with a clear message.
- `generate_skeleton_package`: `instructions_path` is now absolutized once and the absolute
  path used for both the skip-during-copy check and the `_write_student_instructions` call,
  making it robust to working-directory changes between the two points.
- `read_assignment_config`: `mode` value from the config file is now validated as `"student"`
  or `"teacher"` with a clear `ArgumentError`; previously an invalid mode silently became a
  Symbol that only failed much later.

### Added (code quality and correctness — session 1)

- `_strip_code_noise(text)` state-machine preprocessor that replaces comment and
  string-literal content with spaces before property checks, eliminating false
  positives when keywords appear inside comments or string values. Handles `#`
  line comments, `#= ... =#` depth-tracked nested block comments, `"strings"`,
  and `"""triple strings"""`.
- Applied `_strip_code_noise` in `_calls`, `_has_loop`, `_has_global`,
  `_has_side_effects`, `_uses_operator`, `_is_exported`, `_has_import`, and
  `_nested_loop_depth`.
- Eleven module-level `const _RE_*` regex constants in `properties.jl` replacing
  inline `r"..."` literals that were recompiled on every call.
- `_collect_rubric_and_specs(reference_path)` combines the previously separate
  `_collect_rubric` and `_collect_reference_tests` walkdir loops into one pass.
  `_collect_rubric` is now a thin wrapper; `grade_submission` calls the combined
  version.
- `_SCAFFOLDING_PROXIMITY_LINES` named constant (was magic number 8) in
  `validation.jl` with an explanatory comment.
- `_RE_SCAFFOLDING_PROMPT` regex constant for the scaffolding-prompt check,
  improving coverage with `\bmissing\b` word boundary and `unimplemented`.
- `spec::Union{Nothing, Expr}` type annotation on `RubricItem.spec` (was `Any`).
- Docstrings on internal helper functions: `_check_property`, `_source_project`,
  `_source_project_from_path`, `_property_holds`, `_nested_loop_depth`,
  `_validate_package_shape!`, `_validate_file!`, `_parse_marks_line`,
  `_collect_rubric`, `_collect_rubric_and_specs`, `_parse_reference_test_line`,
  `_parse_property_line`, and `_reference_eval_script`.
- Unit test suite for all property-checker functions with edge cases (missing
  function returns false, project-wide vs function-scoped calls).
- `_strip_code_noise` test suite confirming comment, string, and nested block
  comment stripping.

### Fixed (code quality and correctness — session 1)

- Embedded `_project_name` in the reference-test eval script rewired to use
  `TOML.parsefile` (matching the `templates.jl` implementation), eliminating a
  fragile manual line-splitting parser that threw on edge-case Project.toml files.
- Type annotations added to embedded `_collect_block`, `_keep_body`, and
  `_loadable_source` inside the reference eval script.
- Removed unused `root` parameter from `_validate_file!` and its call site.
- Removed unused `behavioral_passed` and `zeroed` parameters from
  `_student_grade_report` and its two call sites.

### Added (grading features — session 2)

- **Gradescope integration** — `grade_submission` accepts `gradescope_path` to
  write a Gradescope autograder JSON file. `GradeResult.gradescope_json` is
  always populated. JSON format follows the
  [Gradescope autograder spec](https://gradescope-autograders.readthedocs.io/en/latest/specs/).
  CLI: `--gradescope PATH`.
- **LMS-ready CSV export** — `csv_format` keyword on `grade_submission` renames
  the student-id column for direct LMS import:
  - `:canvas` → `SIS Login ID` (Canvas grade import)
  - `:moodle` → `username` (Moodle gradebook import)
  - `:blackboard` → `Username` (Blackboard grade center)
  CLI: `--csv-format FORMAT`.
- **Execution timeouts** — `test_timeout_seconds` (default 120) and
  `reference_timeout_seconds` (default 30) keywords kill runaway submission
  processes via `timedwait` + `kill`. `GradeResult.timed_out` records whether
  the main test process was killed. CLI: `--test-timeout N`, `--ref-timeout N`.
- **HTML feedback reports** — `_build_html_report` converts the Markdown student
  report to a self-contained HTML document with inline CSS. Always available as
  `GradeResult.html_report`; written to disk via `html_path` keyword.
  CLI: `--html PATH`.
- **Failure diagnostics** — `_categorize_failure` parses stderr to classify
  grading failures as `:none`, `:load_failure`, `:test_failure`, `:timeout`, or
  `:zero_gate`. Stored in `GradeResult.failure_category` and
  `GradeResult.failure_message`; shown prominently at the top of both Markdown
  and HTML reports.
- **VS Code snippets** — `.vscode/skeletonize.code-snippets` provides nine
  tab-completable annotation snippets for Julia files (`sol`, `scaff`, `stest`,
  `htest`, `marks`, `areqs`, `req`, `forb`, `rtest`).
- **Template library** — two new reference-package examples:
  - `examples/StringProcessingAssignment` — `word_frequencies` and `top_words`
    with reference tests, loop requirements, and forbidden-package gate.
  - `examples/NumericalMethodsAssignment` — `bisect` (bisection root-finding)
    with convergence tolerance, loop requirement, and recursion gate.
- `TODO.md` entries for GitHub Actions integration, incremental grading, Pluto
  notebook support, and partial credit.

### Changed (grading features — session 2)

- `GradeResult` gains five new fields appended after the existing sixteen:
  `timed_out`, `failure_category`, `failure_message`, `gradescope_json`,
  `html_report`.
- `grade_submission` signature extended with new keyword arguments for all new
  features; all existing keyword arguments remain unchanged.
- `_run_reference_tests` and `_evaluate_reference_spec` accept `timeout_seconds`
  keyword; reference tests that time out return a structured error result rather
  than hanging.
- CLI `grade` command updated to accept `--html`, `--gradescope`, `--csv-format`,
  `--test-timeout`, `--ref-timeout`.

### Fixed (grading features — session 2)

- Bold markdown spans (`**text**`) in HTML reports were rendered with one too few
  characters stripped from each end (off-by-one in `_fmt_inline`: `s[3:end-3]`
  → `s[3:end-2]`). Added regression tests.

### Added

- Teacher annotations for splitting a package into teacher and student views:
  `@solution`, `@scaffolding`, `@student_test`, and `@hidden_test`.
- Rubric metadata with `@marks`, plus generated `RUBRIC.md` files for student
  packages.
- Assignment requirement macros: `@assignment_requirements`, `@require`,
  `@forbid`, and `@reference_test`.
- Executable reference tests during grading, comparing submission outputs with
  the teacher reference implementation in isolated Julia processes.
- Source and project property checks for common grading constraints, including
  exported names, method arity, docstrings, imports, calls, recursion, loops,
  comments, lines of code, and nested-loop depth.
- Skeleton package generation from annotated teacher reference packages.
- Teacher package validation with blocking errors and teaching-design warnings.
- A small command-line entry point for validation and generation.
- INC/INI assignment configuration through `SkeletonizePackage.inc`, using the
  format and reader/writer conventions from `IncCSV.jl`.
- Generated `STUDENT_INSTRUCTIONS.md` files, with optional assignment-specific
  Markdown notes.
- Documentation pages for the package pipeline, implementation details,
  requirement macros, and public API.
- Example assignments under `examples/`, including checked-in packages used by
  CI tests.
- `examples/ReferenceOracleAssignment`, demonstrating hidden reference-oracle
  tests with `@reference_test`.
- Step 0 assignment scaffolding with `create_assignment` and the `init` CLI
  command.
- Generated `AGENTS.md` files with configurable `forbidden`, `recorded`, or
  `allowed` AI-use policies.
- A feature-list documentation page summarizing the package capabilities.
- Separate CI coverage for Julia 1.10 and Julia 1.12 package tests, Aqua quality
  checks, and JET static analysis on Julia 1.12.x only.
- Stable rubric IDs and per-criterion grading results.
- Teacher-facing `GRADING_PLAN.md` and `TEACHER_CHECKLIST.md` helpers.
- Additional example assignments for recursive structure requirements and
  forbidden shortcut policies.
- `TODO.md` entries for syntax-aware property checks and batch submission
  grading.
- SVG documentation assets illustrating the package pipeline, annotation
  transformation, and a sorting assignment example.

### Changed

- Split the implementation into focused source files under `src/` to make the
  package easier to navigate and maintain.
- Replaced the earlier TOML assignment configuration path with
  `SkeletonizePackage.inc`.

### Notes

- The package is still pre-release. Public APIs may change as the assignment,
  rubric, and grading model settles.

## 0.1.0

- Initial development version.
