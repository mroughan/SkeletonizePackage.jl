# Contributing

Thanks for helping improve `SkeletonizePackage.jl`. This package is intended to
make Julia teaching assignments easier to write, distribute, and grade, so
contributions are most useful when they keep teacher workflows clear, student
outputs predictable, and grading behaviour easy to audit.

## Development Setup

Use Julia 1.10 or later for normal development. The package supports Julia 1.10+,
while CI also runs Julia 1.12. JET static analysis is intentionally run only on
Julia 1.12.x.

From the repository root:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

Run the ordinary package tests with:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

The ordinary tests use `test/Project.toml`. Aqua and JET use a separate
`test/quality` environment so quality-check dependencies do not affect the main
Julia-version test matrix.

## Quality Checks

Run Aqua checks with:

```bash
julia --project=test/quality -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); include(joinpath(pwd(), "test", "aqua.jl"))'
```

Run JET checks with Julia 1.12.x:

```bash
julia --project=test/quality -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); include(joinpath(pwd(), "test", "jet.jl"))'
```

Please keep the package compatible with Julia 1.10 unless the compatibility
policy is intentionally changed. JET may use newer compiler internals, so it
should remain separate from the ordinary test suite.

## Documentation

Build the documentation with:

```bash
julia --project=docs docs/make.jl
```

When editing documentation, prefer teacher- and student-facing explanations over
internal implementation detail unless the page is specifically about internals.

The current documentation pages are:

- `docs/src/index.md`
- `docs/src/features.md`
- `docs/src/pipeline.md`
- `docs/src/details.md`
- `docs/src/requirements.md`
- `docs/src/api.md`

When adding a new page, register it in `docs/make.jl`.

## Contribution Guidelines

- Keep changes focused and avoid unrelated refactors.
- Keep teacher-only and student-facing behaviour separate and explicit.
- Preserve generated skeleton packages as ordinary Julia packages that students
  can open, instantiate, test, and submit.
- Keep teacher-only material out of generated student skeletons.
- Add or update tests when changing generation, validation, grading, rubric
  extraction, property checks, configuration parsing, report output, or CLI
  behaviour.
- Keep examples in `examples/` runnable and representative, since they are both
  documentation and regression tests.
- Use `SkeletonizePackage.inc` for assignment configuration. It should follow
  the INI format expected by `mroughan/INCspec` and be read/written through
  `mroughan/IncCSV.jl`.
- Document new user-facing annotations, macros, or configuration options in
  `docs/src/` and, when useful, mention them in `README.md`.
- Update `CHANGELOG.md` for notable changes.

When adding requirement properties for `@require` or `@forbid`, prefer checks
that are easy for teachers and students to understand. Source-level properties
are allowed to be conservative heuristics, but their limitations should be
documented.

## Coverage

To measure local coverage:

```bash
julia --project -e 'using Pkg; Pkg.test(; coverage=true)'
```

Generated `.cov` files are local artifacts and should be removed before
committing.

## Pull Requests

Before opening a pull request:

- Run the package tests.
- Run Aqua and JET if your change affects quality checks, inference, exported
  APIs, or shared internals.
- Build the documentation if your change affects docs or public API.
- Check that generated examples still make sense as teaching material.
- Do not commit generated `Manifest.toml` files or `.cov` coverage files.
- Add a short changelog entry under `Unreleased` for notable changes.

Please include a concise explanation of the teaching or maintenance problem the
change solves.
