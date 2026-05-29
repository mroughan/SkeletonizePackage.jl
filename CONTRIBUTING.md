# Contributing

Thanks for helping improve `SkeletonPackages.jl`. The package is intended for
teaching, so contributions should keep the teacher and student experience clear,
auditable, and easy to explain.

## Development Setup

Use Julia 1.10 or later. The package supports Julia 1.10, while CI also runs
Julia 1.12 so newer static-analysis tooling can be checked there.

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

Run the test suite from the repository root:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

Build the documentation with:

```bash
julia --project=docs docs/make.jl
```

## Contribution Guidelines

- Keep teacher-only and student-facing behaviour separate and explicit.
- Prefer small, readable changes over broad rewrites.
- Add or update tests when changing generation, validation, rubric extraction,
  property checks, configuration parsing, or CLI behaviour.
- Keep examples in `examples/` runnable and representative, since they are both
  documentation and regression tests.
- Use `SkeletonPackages.inc` for assignment configuration. It should follow the
  INI format expected by `mroughan/INCspec` and be read/written through
  `mroughan/IncCSV.jl`.
- Document new user-facing annotations, macros, or configuration options in
  `docs/src/` and, when useful, mention them in `README.md`.
- Update `CHANGELOG.md` for notable changes.

## Tests and Quality Checks

The normal local check is:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

The test suite includes Aqua checks and runs JET only on Julia 1.12 or later.
Please keep the package compatible with Julia 1.10 unless the compatibility
policy is intentionally changed.

When adding requirement properties for `@require` or `@forbid`, prefer checks
that are easy for teachers and students to understand. Source-level properties
are allowed to be conservative heuristics, but their limitations should be
documented.

## Documentation

Documentation is built with Documenter. The current documentation pages are:

- `docs/src/index.md`
- `docs/src/pipeline.md`
- `docs/src/details.md`
- `docs/src/requirements.md`
- `docs/src/api.md`

When adding a new page, register it in `docs/make.jl`.

## Pull Requests

Before opening a pull request:

- Run the package tests.
- Build the documentation if your change affects docs or public API.
- Check that generated examples still make sense as teaching material.
- Add a short changelog entry under `Unreleased`.

Please include a concise explanation of the teaching or maintenance problem the
change solves.
