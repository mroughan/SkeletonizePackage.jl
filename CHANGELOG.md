# Changelog

All notable changes to `SkeletonizePackage.jl` are recorded here.

This project follows the spirit of [Keep a Changelog](https://keepachangelog.com/)
and uses semantic versioning once releases begin.

## Unreleased

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
