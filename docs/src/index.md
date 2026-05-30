# SkeletonPackages.jl

`SkeletonPackages.jl` transforms an annotated teacher reference package into a
student skeleton package. Students complete the skeleton to create their
submission package.

The package is intentionally conservative: it uses a small annotation language,
keeps generated packages as ordinary Julia packages, and validates reference
packages before generation so syntax and teaching-design problems are caught
early.

## Quick Start

Start by scaffolding a teacher reference package:

```julia
using SkeletonPackages

create_assignment("MyAssignment"; ai_policy=:recorded)
```

The scaffold is step 0 of the pipeline. It creates a normal Julia package with
example annotations, public and hidden tests, rubric entries, source-property
requirements, a reference-oracle test, exercise notes, and a
`SkeletonPackages.inc` file. Teachers then edit those files into the real
assignment.

The reference package contains annotations such as:

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

Validate it, generate a skeleton, let the student work from that skeleton, and
grade the resulting submission:

```julia
using SkeletonPackages

create_assignment("MyAssignment"; ai_policy=:recorded)

report = validate_reference_package("examples/SortingAssignment"; io=stdout)
isvalid(report)

skeleton = generate_skeleton_package(
    "examples/SortingAssignment",
    "SortingAssignmentStudent";
    force=true,
)

# After distribution, the student edits the skeleton and submits a completed copy.
result = grade_submission(
    "examples/SortingAssignment",
    "SortingAssignmentSubmission";
    student_id="s123",
    report_path="s123-feedback.md",
    csv_path="marks.csv",
)
```

Skeleton packages keep `@starter` and `@student_test` bodies. Reference packages
keep `@solution`, `@student_test`, and `@hidden_test` bodies. Generated skeleton
packages also include `STUDENT_INSTRUCTIONS.md`, a generic guide for students
who are new to Julia package workflows, and `RUBRIC.md`, the student-facing
grading contract. They also include `AGENTS.md`, generated from the configured
AI-use policy. Grading writes a Markdown feedback report for the student and a
CSV row that can be appended to a class marks file.

## Example 1 - Very Thin Example

`examples/ThinAssignment` shows the smallest useful pattern: one exported
function, one reference solution, one starter placeholder, one public test, and
one hidden test. Tests can also carry `@marks` lines that become the generated
skeleton `RUBRIC.md`.

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

Run the complete thin pipeline from the repository root:

```julia
using SkeletonPackages

reference = "examples/ThinAssignment"
skeleton = "ThinAssignmentSkeleton"
submission = "ThinAssignmentSubmission"

validate_reference_package(reference; io=stdout)
generate_skeleton_package(reference, skeleton; force=true)

# In a real class, the student receives `skeleton`, edits it, and submits a copy.
# For local experimentation, copy the skeleton and replace the TODO by hand.
result = grade_submission(reference, submission; student_id="thin-demo")
result.student_report
result.csv_row
```

The reference package remains the teacher's canonical version, the skeleton is
what students see, and the submission is the student's completed package.

## Example 2 - Public and Hidden Tests

`examples/SortingAssignment` demonstrates the common assignment pattern:
students receive a skeleton implementation and public tests, while hidden tests
remain in the reference package for grading.

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

A typical teacher workflow is:

```bash
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- validate examples/SortingAssignment
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate examples/SortingAssignment SortingAssignmentSkeleton --force
```

Students work in `SortingAssignmentSkeleton`, run their public tests with:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

After they submit a completed package, the teacher can grade it:

```bash
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- grade examples/SortingAssignment SortingAssignmentSubmission --student-id s123 --report s123-feedback.md --csv marks.csv
```

The grading step produces `s123-feedback.md` for the student and appends a row
to `marks.csv` for the class marks spreadsheet.

## Example 3 - Configuration Options

`examples/ConfiguredAssignment` includes a `SkeletonPackages.inc` file. The
configuration lives in the INC metadata block, using the INI-style metadata
syntax defined by INCspec and read/written by IncCSV.jl.

```text
---
[assignment]
reference_path = "."
skeleton_path = "../ConfiguredAssignmentStudent"
mode = "student"
force = false
validate = true
instructions_path = "student_notes.md"
ai_policy = "recorded"
---
config
assignment
```

Generate from the config file with:

```julia
using SkeletonPackages

config = read_assignment_config("examples/ConfiguredAssignment/SkeletonPackages.inc")
generate_skeleton_package(config; io=stdout)
```

`instructions_path` points to exercise-specific Markdown that is transformed in
student mode before being appended to `STUDENT_INSTRUCTIONS.md`. `ai_policy`
can be `forbidden`, `recorded`, or `allowed`; it controls the generated
`AGENTS.md` file in the student skeleton.

The generated configured skeleton contains:

```text
ConfiguredAssignmentStudent/
  Project.toml
  STUDENT_INSTRUCTIONS.md
  AGENTS.md
  RUBRIC.md
  src/
  test/
```

The same reference package can then be used to grade each submitted copy:

```julia
grade_submission(
    config.reference_path,
    "ConfiguredAssignmentSubmission";
    student_id="configured-demo",
    report_path="configured-feedback.md",
    csv_path="configured-marks.csv",
)
```

## Example 4 - Reference Oracle Tests

`examples/ReferenceOracleAssignment` demonstrates hidden tests that compare the
student submission directly with the teacher's reference implementation.

```julia
@hidden_test begin
    @marks 3 "matches the reference implementation on generated inputs"
    @reference_test clamp01 generator=[-2, -0.5, 0, 0.25, 1, 2]
end
```

During grading, `grade_submission` evaluates `clamp01` on the reference package
and on the submitted package in separate Julia processes, then compares the
outputs. A passing report contains entries like:

```text
## Reference Tests

- [hidden] `clamp01` input 1 passed: matched reference output
```
