# Pipeline

`SkeletonizePackage.jl` is built around a setup to reference to skeleton to
submission pipeline:

```text
0. create_assignment(...)
  |
  v
X.jl  teacher reference package
  |
  | generate_skeleton_package(...)
  v
Y.jl  student skeleton package
  |
  | student completes
  v
Z.jl  student submission package
  |
  | grade_submission(...)
  v
feedback/report
```

## Worked Pipeline

The checked-in examples can be used to exercise the whole flow. Teachers can
begin from a scaffolded reference package:

```bash
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- init MyAssignment --ai-policy recorded
```

Then generate a student skeleton and grade a submitted package:

```bash
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- validate examples/SortingAssignment
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- generate examples/SortingAssignment SortingAssignmentSkeleton --force --ai-policy recorded
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- grade examples/SortingAssignment SortingAssignmentSubmission --student-id s123 --report s123-feedback.md --csv marks.csv
```

The generated skeleton is the package distributed to students:

```text
SortingAssignmentSkeleton/
  Project.toml
  README.md
  STUDENT_INSTRUCTIONS.md
  AGENTS.md
  RUBRIC.md
  src/
  test/
```

The student's submitted package is graded against the original reference
package. The grading command writes two different outputs: a Markdown feedback
report for the student, and a CSV row for the teacher's marks table.

Teacher scaffolds also include `GRADING_PLAN.md` and `TEACHER_CHECKLIST.md`.
These files stay with the teacher reference package and are not copied into the
student skeleton.

## Configuration

Assignment generation can be configured with `SkeletonizePackage.inc`:

```text
---
[assignment]
reference_path = "examples/SortingAssignment"
skeleton_path = "SortingAssignmentStudent"
mode = "student"
force = false
validate = true
instructions_path = "student_notes.md"
ai_policy = "recorded"
---
config
assignment
```

Then run:

```julia
generate_skeleton_package("SkeletonizePackage.inc")
```

`reference_path`, `skeleton_path`, `mode`, `force`, `validate`, and `ai_policy`
belong under `[assignment]`. `instructions_path` and `ai_policy` may also be
placed under `[student]`. Relative paths are resolved from the config file's
directory. If `instructions_path` is omitted and the reference package contains
`student_notes.md`, it is included automatically.

`ai_policy` controls the generated `AGENTS.md` file:

- `forbidden`: AI agents are strictly forbidden for the assignment.
- `recorded`: AI use is allowed only when actions are recorded for audit.
- `allowed`: AI use is allowed, subject to the teacher's normal rules.

## Annotation

The supported annotations are:

```julia
@solution      # teacher-only implementation
@scaffolding       # replacement shown to students
@student_test  # tests included in the generated skeleton
@hidden_test   # teacher-only grading tests
@marks         # rubric metadata attached to nearby tests
@require       # grading metadata: code property that must hold
@forbid        # grading metadata: code property that must not hold
```

Annotation openers must appear on their own line:

```julia
@solution begin
    # teacher-only body
end
```

Inline forms are reported by `validate_reference_package` and are not
transformed.

Rubric metadata can be placed inside public or hidden test blocks:

```julia
@hidden_test begin
    @marks 2 "handles empty vectors"
    @test mysort(Int[]) == Int[]
end
```

The generated skeleton package includes `RUBRIC.md`. Hidden test code remains
private, but the `@marks` description tells students what behaviour will be
graded. Generated test blocks become named `@testset`s. Prefer one coherent
`@marks` criterion per block.

## Skeleton Generation

`generate_skeleton_package` copies a Julia package, transforms `.jl`, `.md`,
`.toml`, and `.inc` files, and skips teacher-only directories such as `.git`,
`build`, and `solutions`. Common editor backup files ending in `~` or wrapped in
`#...#` are also omitted.

For `mode = :student`, it removes `@solution` and `@hidden_test` bodies, and
keeps `@scaffolding` and `@student_test` bodies. For `mode = :teacher`, it keeps
`@solution`, `@student_test`, and `@hidden_test` bodies, and removes
`@scaffolding` bodies. In transformed Julia files, kept test blocks become named
`@testset`s.

If the destination exists, pass `force=true`.

Generation also writes:

- `README.md`, identifying the package as a student skeleton and directing
  students to the generated Markdown guidance.
- `STUDENT_INSTRUCTIONS.md`, with generic package workflow guidance plus any
  configured exercise notes and a layout describing copied directories such as
  `data/`.
- `RUBRIC.md`, generated from `@marks`, `@require`, and `@forbid`.
- `AGENTS.md`, generated from `ai_policy` with explicit AI-use instructions.

`create_assignment(...)` also writes teacher-only `GRADING_PLAN.md` and
`TEACHER_CHECKLIST.md`. They can be refreshed with `write_grading_plan(...)`
and `write_teacher_checklist(...)`.

## Checking Student Work

Run validation before handing a skeleton to students:

```julia
report = validate_reference_package(
    "examples/SortingAssignment";
    io=stdout,
    run_tests=true,
)
isvalid(report)
```

Validation errors block generation when `validate=true`. Warnings and notes are
teacher-facing design feedback, for example missing public tests, hidden tests,
scaffolding blocks that do not look like student prompts, annotated source files
that are not included by the package, or package/module naming mismatches.
Generation and the `validate` command also run the reference behavioural tests
and warn when they fail. For direct API calls, request this explicitly with
`validate_reference_package(path; run_tests=true)`.

`grade_submission` runs a submission package's tests in an isolated Julia
process and returns a `GradeResult`. The result contains `student_report` for
student feedback, plus `csv_header` and `csv_row` for a marks table with one row
per student.

```julia
result = grade_submission(
    "examples/SortingAssignment",
    "SortingAssignmentSubmission";
    student_id="s123",
    report_path="s123-feedback.md",
    csv_path="marks.csv",
)

result.student_report
result.csv_row
```

The grading harness summarizes marks by rubric visibility, such as `public` and
`hidden`, and totals them at the end of the CSV row. Property and reference-test
criteria are evaluated separately. Ordinary behavioural `@marks` criteria are
currently inferred from the overall submission test result, so teachers should
prefer one coherent marked behaviour per test block.
