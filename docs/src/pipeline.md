# Pipeline

`SkeletonPackages.jl` is built around a teacher package to student package
pipeline:

```text
X.jl  teacher reference package
  |
  | generate_student_package(...)
  v
Y.jl  student starter package
  |
  | student completes
  v
Z.jl  student submission package
  |
  | grade_submission(...)
  v
feedback/report
```

## Configuration

Assignment generation can be configured with `SkeletonPackages.inc`:

```text
---
[assignment]
source_path = "examples/SortingAssignment"
student_path = "SortingAssignmentStudent"
mode = "student"
force = false
validate = true
instructions_path = "student_notes.md"
---
config
assignment
```

Then run:

```julia
generate_student_package("SkeletonPackages.inc")
```

`source_path`, `student_path`, `mode`, `force`, and `validate` belong under
`[assignment]`. `instructions_path` is optional and may also be placed under
`[student]`. Relative paths are resolved from the config file's directory.

## Annotation

The supported annotations are:

```julia
@solution      # teacher-only implementation
@starter       # replacement shown to students
@student_test  # tests included in the generated starter
@hidden_test   # teacher-only grading tests
@marks         # rubric metadata attached to nearby tests
@require       # code property that must hold
@forbid        # code property that must not hold
```

Annotation openers must appear on their own line:

```julia
@solution begin
    # teacher-only body
end
```

Inline forms are reported by `validate_teacher_package` and are not
transformed.

Rubric metadata can be placed inside public or hidden test blocks:

```julia
@hidden_test begin
    @marks 2 "handles empty vectors"
    @test mysort(Int[]) == Int[]
end
```

The generated student package includes `RUBRIC.md`. Hidden test code remains
private, but the `@marks` description tells students what behaviour will be
graded.

## Skeleton Generation

`generate_student_package` copies a Julia package, transforms `.jl`, `.md`,
`.toml`, and `.inc` files, and skips teacher-only directories such as `.git`,
`build`, and `solutions`.

For `mode = :student`, it removes `@solution` and `@hidden_test` bodies, and
keeps `@starter` and `@student_test` bodies. For `mode = :teacher`, it keeps
`@solution`, `@student_test`, and `@hidden_test` bodies, and removes
`@starter` bodies.

If the destination exists, pass `force=true`.

## Checking Student Work

Run validation before handing an assignment to students:

```julia
report = validate_teacher_package("examples/SortingAssignment"; io=stdout)
isvalid(report)
```

Validation errors block generation when `validate=true`. Warnings and notes are
teacher-facing design feedback, for example missing public tests, hidden tests,
or starter blocks that do not look like student prompts.

`grade_submission` runs a student package's tests in an isolated Julia process
and returns a `GradeResult`.
