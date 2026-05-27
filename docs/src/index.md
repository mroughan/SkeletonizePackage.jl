# SkeletonPackages.jl

`SkeletonPackages.jl` generates student starter packages from annotated teacher solution packages.

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
keep `@solution`, `@student_test`, and `@hidden_test` bodies.

If the destination exists, pass `force=true`.

Generated student packages also include `STUDENT_INSTRUCTIONS.md`, which explains
the package layout, `julia --project=.`, `Pkg.instantiate()`, and `Pkg.test()` for
students who are new to Julia package workflows.

## Validation

Run validation before handing an assignment to students:

```julia
report = validate_teacher_package("examples/SortingAssignment"; io=stdout)
isvalid(report)
```

Validation errors block generation when `validate=true`. Warnings and notes are
teacher-facing design feedback, for example missing public tests, hidden tests,
or starter blocks that do not look like student prompts. Julia files are also
parsed before and after transformation so broken generated source is caught
early.

## Configuration

Assignment generation can be configured with `SkeletonPackages.toml`:

```toml
[assignment]
source_path = "examples/SortingAssignment"
student_path = "SortingAssignmentStudent"
mode = "student"
force = false
validate = true
```

Then run:

```julia
generate_student_package("SkeletonPackages.toml")
```

## Templates

Create a small teacher-package template with:

```julia
create_assignment("MyAssignment")
```

## Annotation Contract

The current transformer is line-oriented. Put each annotation opener on its own
line:

```julia
@solution begin
    # teacher-only code
end
```

Inline annotations are not supported yet.

Supported annotations are `@solution`, `@starter`, `@student_test`, and
`@hidden_test`.

## Command Line

The package exposes a small CLI-style entry point:

```bash
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- validate examples/SortingAssignment
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate examples/SortingAssignment SortingAssignmentStudent --force
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- init MyAssignment
```

## API Reference

```@docs
@solution
@starter
@student_test
@hidden_test
AssignmentConfig
GradeResult
ValidationIssue
ValidationReport
create_assignment
generate_student_package
grade_submission
main
read_assignment_config
strip_teacher_annotations
validate_teacher_package
```
