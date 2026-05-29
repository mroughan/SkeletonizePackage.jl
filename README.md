# SkeletonPackages.jl

[![CI](https://github.com/mroughan/SkeletonPackages.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/mroughan/SkeletonPackages.jl/actions/workflows/CI.yml)
[![Documentation](https://github.com/mroughan/SkeletonPackages.jl/actions/workflows/Documentation.yml/badge.svg)](https://github.com/mroughan/SkeletonPackages.jl/actions/workflows/Documentation.yml)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://mroughan.github.io/SkeletonPackages.jl/dev/)
[![codecov](https://codecov.io/gh/mroughan/SkeletonPackages.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/mroughan/SkeletonPackages.jl)
[![Julia](https://img.shields.io/badge/julia-1.10%2B-blue.svg)](https://julialang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`SkeletonPackages.jl` is a teaching-oriented metapackage for generating student
starter packages from teacher solution packages.

## Quick start

From Julia, generate a student package from the included example:

```julia
using SkeletonPackages

generate_student_package("examples/SortingAssignment", "SortingAssignmentStudent")
```

The generated package keeps starter implementations and public tests, while
removing solution blocks and hidden tests. It also adds
`STUDENT_INSTRUCTIONS.md`, a generic guide for students who are new to Julia
packages, local environments, dependency installation, and running tests.

If the destination already exists, pass `force=true`:

```julia
generate_student_package("examples/SortingAssignment", "SortingAssignmentStudent"; force=true)
```

You can also validate the teacher package before generating:

```julia
report = validate_teacher_package("examples/SortingAssignment"; io=stdout)
isvalid(report)
```

Or use the small command-line entry point:

```bash
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- validate examples/SortingAssignment
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate examples/SortingAssignment SortingAssignmentStudent
```

![SkeletonPackages.jl workflow pipeline](assets/workflow-pipeline.svg)

At generation time, `SkeletonPackages.jl` keeps student-facing scaffolding and
removes teacher-only material:

![Annotation transformation from teacher package to student package](assets/annotation-transform.svg)

## Teacher annotations

```julia
function mysort(xs)
    @solution begin
        return sort(xs)
    end
    @starter begin
        error("TODO: implement mysort")
    end
end
```

Supported annotation openers must appear on their own line:

```julia
@solution begin
    # teacher-only body
end
```

Inline annotation forms are reported by `validate_teacher_package` and are not
transformed.

Visible and hidden tests can be marked similarly:

```julia
@student_test begin
    @marks 1 "sorts a simple input"
    @test mysort([2,1]) == [1,2]
end

@hidden_test begin
    @marks 1 "handles a longer hidden input"
    @test mysort([3,1,2]) == [1,2,3]
end
```

`@marks` is rubric metadata. It is a runtime no-op, but generated student
packages include a `RUBRIC.md` file summarizing public and hidden grading
criteria without revealing hidden test code.

Broader code requirements can be grouped similarly:

```julia
@assignment_requirements begin
    @require exported(mysort)
    @require docstring(mysort)
    @forbid imports(DataFrames)
    @reference_test mysort generator=1:10
end
```

The included `SortingAssignment` example shows how the same annotations affect
both source code and tests:

![SortingAssignment annotation example](assets/sorting-assignment-example.svg)

Then generate the student version:

```julia
using SkeletonPackages

generate_student_package("SortingAssignment", "SortingAssignmentStudent")
```

## Examples

See `examples/SortingAssignment` for a minimal annotated teacher package. It
contains:

- `@solution` code that runs in the teacher package.
- `@starter` code that appears in the generated student package.
- `@student_test` tests that students can see.
- `@hidden_test` tests that teachers can keep for grading.
- `@marks` metadata that appears in the generated `RUBRIC.md`.

To create a new starter teacher package:

```julia
create_assignment("MyAssignment")
```

This writes a small package template and a `SkeletonPackages.inc` config file.
The config can be used directly:

```julia
generate_student_package("MyAssignment/SkeletonPackages.inc")
```

The config can also include exercise-specific student instructions:

```text
---
[assignment]
source_path = "."
student_path = "../MyAssignmentStudent"
instructions_path = "student_notes.md"
---
config
assignment
```

When `instructions_path` is set, that Markdown file is appended to the generated
`STUDENT_INSTRUCTIONS.md` under an "Exercise-Specific Instructions" heading.
Annotation blocks in the Markdown file are transformed in student mode, so
`@starter` content is kept and `@solution` content is removed.

## Current status

This is still an early package, but it now validates teacher packages before
generation and reports both blocking transformation errors and teaching-design
warnings. Validation also checks that Julia source parses before and after
annotation removal. The transformer remains conservative: annotation macros must
appear on their own line. Future versions may replace the text transformer with
a concrete syntax tree transformation using `JuliaSyntax.jl` or a similar parser.

## AI use disclosure

This package includes documentation, tests, and project scaffolding that were
drafted or revised with assistance from OpenAI's Codex. Human review remains
responsible for correctness, package design, and release decisions.
