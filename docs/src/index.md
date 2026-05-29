# SkeletonPackages.jl

`SkeletonPackages.jl` generates student starter packages from annotated teacher
solution packages. A teacher writes a normal Julia package, marks solution-only
and student-facing regions, and then generates a package that students can
complete and submit.

The package is intentionally conservative: it uses a small annotation language,
keeps generated packages as ordinary Julia packages, and validates teacher
packages before generation so syntax and teaching-design problems are caught
early.

## Quick Start

Add annotation blocks to a teacher package:

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

Then generate a student-facing copy:

```julia
using SkeletonPackages

generate_student_package("examples/SortingAssignment", "SortingAssignmentStudent")
```

Student packages keep `@starter` and `@student_test` bodies. Teacher packages
keep `@solution`, `@student_test`, and `@hidden_test` bodies. Generated student
packages also include `STUDENT_INSTRUCTIONS.md`, a generic guide for students
who are new to Julia package workflows.

## Example 1 - Very Thin Example

`examples/ThinAssignment` shows the smallest useful pattern: one exported
function, one teacher solution, one starter placeholder, one public test, and
one hidden test. Tests can also carry `@marks` lines that become the generated
student `RUBRIC.md`.

```julia
function double_it(x)
    @solution begin
        return 2x
    end
    @starter begin
        error("TODO: implement double_it")
    end
end
```

This is a good starting point when introducing the annotation model without
configuration or richer testing concerns.

## Example 2 - Public and Hidden Tests

`examples/SortingAssignment` demonstrates the common assignment pattern:
students receive a starter implementation and public tests, while hidden tests
remain in the teacher package for grading.

```julia
@student_test begin
    @marks 1 "sorts a simple two-element vector"
    @test mysort([2, 1]) == [1, 2]
end

@hidden_test begin
    @marks 1 "handles empty vectors"
    @test mysort(Int[]) == Int[]
end
```

## Example 3 - Configuration Options

`examples/ConfiguredAssignment` includes a `SkeletonPackages.inc` file. The
configuration lives in the INC metadata block, using the INI-style metadata
syntax defined by INCspec and read/written by IncCSV.jl.

```text
---
[assignment]
source_path = "."
student_path = "../ConfiguredAssignmentStudent"
mode = "student"
force = false
validate = true
instructions_path = "student_notes.md"
---
config
assignment
```

Generate from the config file with:

```julia
generate_student_package("examples/ConfiguredAssignment/SkeletonPackages.inc")
```

`instructions_path` points to exercise-specific Markdown that is transformed in
student mode before being appended to `STUDENT_INSTRUCTIONS.md`.
