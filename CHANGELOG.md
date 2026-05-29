# Changelog

All notable changes to `SkeletonPackages.jl` are recorded here.

This project follows the spirit of [Keep a Changelog](https://keepachangelog.com/)
and uses semantic versioning once releases begin.

## Unreleased

### Added

- Teacher annotations for splitting a package into teacher and student views:
  `@solution`, `@starter`, `@student_test`, and `@hidden_test`.
- Rubric metadata with `@marks`, plus generated `RUBRIC.md` files for student
  packages.
- Assignment requirement macros: `@assignment_requirements`, `@require`,
  `@forbid`, and `@reference_test`.
- Source and project property checks for common grading constraints, including
  exported names, method arity, docstrings, imports, calls, recursion, loops,
  comments, lines of code, and nested-loop depth.
- Student package generation from annotated teacher packages.
- Teacher package validation with blocking errors and teaching-design warnings.
- A small command-line entry point for validation and generation.
- INC/INI assignment configuration through `SkeletonPackages.inc`, using the
  format and reader/writer conventions from `IncCSV.jl`.
- Generated `STUDENT_INSTRUCTIONS.md` files, with optional assignment-specific
  Markdown notes.
- Documentation pages for the package pipeline, implementation details,
  requirement macros, and public API.
- Example assignments under `examples/`, including checked-in packages used by
  CI tests.
- CI coverage for Julia 1.10 and Julia 1.12, with JET analysis enabled on Julia
  1.12 or later.
- SVG documentation assets illustrating the package pipeline, annotation
  transformation, and a sorting assignment example.

### Changed

- Split the implementation into focused source files under `src/` to make the
  package easier to navigate and maintain.
- Replaced the earlier TOML assignment configuration path with
  `SkeletonPackages.inc`.

### Notes

- The package is still pre-release. Public APIs may change as the assignment,
  rubric, and grading model settles.

## 0.1.0

- Initial development version.
