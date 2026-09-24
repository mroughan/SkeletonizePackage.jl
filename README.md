# SkeletonizePackage.jl

[![CI](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/CI.yml)
[![Aqua](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/Aqua.yml/badge.svg)](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/Aqua.yml)
[![JET](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/JET.yml/badge.svg)](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/JET.yml)
[![Documentation](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/documentation.yml/badge.svg)](https://github.com/mroughan/SkeletonizePackage.jl/actions/workflows/documentation.yml)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://mroughan.github.io/SkeletonizePackage.jl/dev/)
[![codecov](https://codecov.io/gh/mroughan/SkeletonizePackage.jl/branch/main/graph/badge.svg?token=pMUMsG0QuO)](https://app.codecov.io/gh/mroughan/SkeletonizePackage.jl)
[![Julia](https://img.shields.io/badge/julia-1.10%2B-blue.svg)](https://julialang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`SkeletonizePackage.jl` is a teaching-oriented metapackage for transforming a
teacher reference package into a student skeleton package. Students complete the
skeleton to create their submission package.

## Features 

- Start a new assignment from a working teacher scaffold, complete with source
  files, tests, assignment notes, a README, and a `SkeletonizePackage.inc`
  configuration file.
- Write one annotated reference package, then generate the student skeleton from
  it. Students see scaffolding and public tests; teacher solutions and hidden
  tests stay private.
- Generate the useful paperwork automatically: a student-skeleton README,
  student instructions, a student-facing rubric, an AI-use policy file, a broad
  teacher grading plan, and a preparation checklist.
- Attach marks directly to tests and code requirements, give criteria stable
  IDs, and turn serious shortcut violations into whole-assignment zero gates
  when needed.
- Check more than final answers: require exports, signatures, docstrings,
  recursion, loops, comments, or line-count limits, and forbid shortcut imports,
  calls, globals, operators, or side-effect patterns.
- Compare student functions against the teacher implementation with hidden
  reference-oracle tests over explicit or generated inputs.
- Grade submissions into readable Markdown feedback and CSV rows suitable for a
  class marks spreadsheet.
- Use either Julia functions or the small command-line workflow for `init`,
  `validate`, `generate`, and `grade`.

## Quick start

From Julia, run the pipeline on the included `SortingAssignment` reference
example:

```julia
using SkeletonizePackage

reference = "examples/SortingAssignment"
skeleton = "SortingAssignmentSkeleton"
submission = "SortingAssignmentSubmission"

validate_reference_package(reference; io=stdout, run_tests=true)
generate_skeleton_package(reference, skeleton; force=true)
grade_submission(
    reference,
    submission;
    student_id="s123",
    report_path="s123-feedback.md",
    csv_path="marks.csv",
)
```

The generated skeleton keeps scaffolding implementations and public tests, while
removing solution blocks and hidden tests. It also writes a student-skeleton
`README.md`, `STUDENT_INSTRUCTIONS.md`, `RUBRIC.md`, and `AGENTS.md`. The
instructions explain package workflows, marks, and copied directories such as
`data/`.

If the skeleton destination already exists, pass `force=true`:

```julia
generate_skeleton_package("examples/SortingAssignment", "SortingAssignmentSkeleton"; force=true)
```

You can also validate the reference package before generating:

```julia
report = validate_reference_package(
    "examples/SortingAssignment";
    io=stdout,
    run_tests=true,
)
isvalid(report)
```

Generation and the CLI `validate` command run reference behavioral tests
automatically and warn when a public or hidden test fails. Direct API validation
only runs tests when `run_tests=true`.

Or use the small command-line entry point:

```bash
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- validate examples/SortingAssignment
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- generate examples/SortingAssignment SortingAssignmentSkeleton --force --ai-policy recorded
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- grade examples/SortingAssignment SortingAssignmentSubmission --student-id s123 --report s123-feedback.md --csv marks.csv
```

To start a fresh assignment instead of using the checked-in example, scaffold a
teacher package and then generate from its config:

```julia
create_assignment("MyAssignment"; ai_policy=:recorded)
generate_skeleton_package("MyAssignment/SkeletonizePackage.inc")
```

![SkeletonizePackage.jl workflow pipeline](assets/workflow-pipeline.svg)

At generation time, `SkeletonizePackage.jl` keeps student-facing scaffolding in
the skeleton and removes teacher-only reference material:

![Annotation transformation from reference package to skeleton package](assets/annotation-transform.svg)

## Teacher annotations

```julia
function mysort(xs)
    @solution begin
        return sort(xs)
    end
    @scaffolding begin
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

Inline annotation forms are reported by `validate_reference_package` and are not
transformed.

Visible and hidden tests can be marked similarly:

```julia
@student_test begin
    @marks 1 "sorts a simple input" id="sort-simple"
    @test mysort([2,1]) == [1,2]
end

@hidden_test begin
    @marks 1 "handles a longer hidden input" id="sort-hidden-longer"
    @test mysort([3,1,2]) == [1,2,3]
end
```

`@marks` is rubric metadata. It is a runtime no-op, but generated skeleton
packages include a `RUBRIC.md` file summarizing public and hidden grading
criteria without revealing hidden test code. Generated test blocks become named
`@testset`s using their first `@marks` description. Prefer one coherent marked
criterion per block.

Broader code requirements can be grouped similarly:

```julia
@assignment_requirements begin
    @require exported(mysort)
    @require docstring(mysort) marks=1 id="mysort-docstring" "documents mysort"
    @forbid imports(DataFrames) zero_marks=true "does not use a shortcut package"
    @reference_test mysort generator=1:10
end
```

`id="..."` gives a criterion a stable identifier in `RUBRIC.md`, feedback, and
grading output. `marks=N` assigns marks to a required or forbidden property.
`zero_marks=true` makes the property a whole-assignment gate: if it fails during
grading, the student gets zero for the assignment.

`@require`, `@forbid`, and `@assignment_requirements` are grading metadata and
runtime no-ops. A reference solution may deliberately omit a student-required
export or docstring; all public and hidden behavioral tests should still pass.

Reference tests can compare a submission against the teacher implementation
during grading:

```julia
@hidden_test begin
    @marks 3 "matches the reference implementation on generated inputs"
    @reference_test clamp01 generator=[-2, -0.5, 0, 0.25, 1, 2]
end
```

See `examples/ReferenceOracleAssignment` for a complete package using this
pattern.

The included `SortingAssignment` example shows how the same annotations affect
both source code and tests:

![SortingAssignment annotation example](assets/sorting-assignment-example.svg)

Then generate the skeleton version:

```julia
using SkeletonizePackage

generate_skeleton_package("examples/SortingAssignment", "SortingAssignmentSkeleton"; force=true)
```

After students submit completed packages, grade each submission against the same
reference package:

```julia
grade_submission(
    "examples/SortingAssignment",
    "SortingAssignmentSubmission";
    student_id="s123",
    report_path="s123-feedback.md",
    csv_path="marks.csv",
)
```

## Examples

See `examples/SortingAssignment` for a minimal annotated reference package. It
contains:

- `@solution` code that runs in the reference package.
- `@scaffolding` code that appears in the generated skeleton package.
- `@student_test` tests that students can see.
- `@hidden_test` tests that teachers can keep for grading.
- `@marks` metadata that appears in the generated `RUBRIC.md`.
- stable rubric IDs and teacher-facing `GRADING_PLAN.md` /
  `TEACHER_CHECKLIST.md` files when using the scaffold. The grading plan records
  broad assessment design; detailed criteria live beside tests.

To create a new reference package template as step 0 of the pipeline:

```julia
create_assignment("MyAssignment"; ai_policy=:recorded)
```

This writes a small package template, `README.md`, `student_notes.md`, public
and hidden tests, rubric/property/reference-test examples, and a
`SkeletonizePackage.inc` config file. The config can be used directly:

```julia
generate_skeleton_package("MyAssignment/SkeletonizePackage.inc")
```

The config can also include exercise-specific student instructions:

```text
---
[assignment]
reference_path = "."
skeleton_path = "../MyAssignmentStudent"
instructions_path = "student_notes.md"
ai_policy = "recorded"
copy_paths = "Project.toml, SkeletonizePackage.inc, src, test, data"
---
config
assignment
```

When `instructions_path` is set, that Markdown file is appended to the generated
`STUDENT_INSTRUCTIONS.md` under an "Exercise-Specific Instructions" heading. If
it is omitted and the reference root contains `student_notes.md`, that file is
included automatically. Annotation blocks in the Markdown file are transformed
in student mode, so `@scaffolding` content is kept and `@solution` content is
removed.

Generation copies only configured student-facing paths. If `copy_paths` is
omitted, the default is `Project.toml`, `SkeletonizePackage.inc`, `src`, `test`,
and `data`. Add extra files or directories only when they should be distributed
to students, for example:

```text
copy_paths = "Project.toml, SkeletonizePackage.inc, src, test, data, assets"
```

Validation warns about root files or directories that are not listed in
`copy_paths`, because they will not be copied into the student skeleton.

`ai_policy` controls the generated `AGENTS.md` file. It can be:

- `forbidden`: AI agents and AI coding assistants are strictly forbidden.
- `recorded`: AI use is permitted only when actions, prompts, outputs, and file
  changes are recorded for audit.
- `allowed`: AI use is allowed, while students remain responsible for
  correctness and academic-integrity requirements.

## Grading outputs

See the [Grading and Diagnostics guide](docs/src/grading.md) for the complete
workflow, scoring policies, result statuses, and dependency troubleshooting.

`grade_submission(reference_path, submission_path)` grades a student submission
against the reference package rubric. By default it runs the teacher's original
`test/runtests.jl` against the submitted package, so changed tests in a student
submission do not affect automarking. The returned `GradeResult` includes:

- `student_report`: Markdown feedback for the student.
- `html_report`: The same feedback as a self-contained HTML document.
- `gradescope_json`: A Gradescope autograder JSON string (always populated).
- `csv_header` and `csv_row`: a one-row marks summary for class-scale CSV files.
- `test_results`: per-group status, assertion counts, and failure details, including
  a root summary whose counts already include all groups.
- `failure_category`: distinguishes assertion failures (`:test_failure`), test
  exceptions (`:test_error`), dependency issues (`:environment_failure`), code or
  precompilation failures (`:load_failure`), unexpected process problems
  (`:execution_failure`), reference-oracle failures (`:reference_failure`),
  property failures (`:property_failure`), `:timeout`, `:zero_gate`, and `:none`.
- `timed_out`: `true` when the submission test process was killed by the timeout.

### Keyword options

| Keyword | Default | Description |
|---|---|---|
| `student_id` | `basename(submission_path)` | Identifier in reports and CSV |
| `test_path` | `reference/test/runtests.jl` | Alternate teacher-owned test entry point |
| `report_path` | `nothing` | Write Markdown report to file |
| `html_path` | `nothing` | Write HTML report to file |
| `gradescope_path` | `nothing` | Write Gradescope JSON to file |
| `csv_path` | `nothing` | Write CSV marks row to file |
| `csv_format` | `:default` | Rename student-id column for LMS import |
| `append_csv` | `true` | Append to `csv_path` rather than overwrite |
| `test_timeout_seconds` | `120` | Kill submission test process after N seconds (0 = no limit) |
| `reference_timeout_seconds` | `30` | Per-reference-test subprocess timeout |
| `zero_on_failure` | `false` | Also zero property marks after any behavioral failure |
| `io` | `stderr` | Brief failure diagnostic destination; `nothing` silences it |

### Complete feedback with zero marks

Grading continues after failed assertions and reports each public and hidden
test group. The default scoring policy is unchanged: any behavioral failure
withholds all ordinary `@marks` points; property points remain independent.
`zero_on_failure=true` instead makes the entire assignment zero after such a
failure. Fatal `zero_marks=true` requirements also zero the entire assignment.
Neither policy hides what passed: `CriterionResult.passed` describes the test
outcome, while `awarded` describes the score.

When either whole-assignment zero policy fires, the report begins with
**ASSIGNMENT ZEROED**, naming the triggering checks and available file/line
locations. Fatal properties show the reference rule's declaration location;
assertion failures show Julia's recorded test location. The brief diagnostic,
HTML banner, and Gradescope summary repeat the warning. All zeroing causes are
listed in the report; the brief summary shows up to three and flags any others.
The underlying failure category is retained, including environment errors.

```julia
result = grade_submission(reference, submission;
    zero_on_failure=true,
    report_path="feedback.md",
)
result.test_results
```

The CLI accepts `--zero-on-failure` and prints a brief failure diagnostic even
when reports are saved to files. Julia callers can use `io=nothing` to silence
that diagnostic. Full exception details and file/line locations remain in the
report's Test Output section.

A failed `@test` does not stop later assertions. An exception outside an assertion
skips the rest of its group, but later independent groups still run. A top-level
setup/import failure, an explicit process exit, or a timeout can prevent further
execution. Reports preserve completed results and identify incomplete or unrun
criteria. Broken/skipped assertions are counted separately; a group containing
only skipped assertions earns no behavioral marks. Use ordinary `@testset`s;
explicit third-party testset types are reported as unsupported.

Dependency and precompilation failures are not evidence that an answer is wrong.
Inspect the named package and underlying exception, check the submission's
`Project.toml`/`Manifest.toml`, and instantiate its environment before retrying.
The grader uses the submission environment with the examiner's active project
as a fallback for test tooling. It does not install packages or rewrite the
submission. Diagnostics identify the observed failure, but cannot always decide
whether the student, the reference tests, or the examiner's environment caused it.

Review reports before sharing them with students: assertion expressions, inputs,
exceptions, and source locations can disclose hidden-test details. The reports
are not automatically redacted. Grading runs in separate processes, not a
security sandbox. The continuation policy applies to the grader, not to an
ordinary student `Pkg.test()` run. `zero_on_failure` is not an INC config option.

### LMS-ready CSV export

Set `csv_format` to rename the student-id column to match your LMS grade-import
format:

```julia
grade_submission(reference, submission;
    csv_path="marks.csv",
    csv_format=:canvas,        # renames to "SIS Login ID"
    # csv_format=:moodle,      # renames to "username"
    # csv_format=:blackboard,  # renames to "Username"
)
```

### Gradescope integration

Pass `gradescope_path` to write a [Gradescope autograder JSON
file](https://gradescope-autograders.readthedocs.io/en/latest/specs/) alongside
the other outputs. The JSON includes per-criterion scores, visibility, and stable
rubric IDs:

```julia
grade_submission(reference, submission;
    student_id="s123",
    gradescope_path="/autograder/results/results.json",
)
```

### HTML feedback reports

Pass `html_path` to write a styled HTML feedback report:

```julia
grade_submission(reference, submission;
    student_id="s123",
    report_path="s123-feedback.md",
    html_path="s123-feedback.html",
)
```

The HTML report is also always available as `result.html_report` without writing
to disk.

The CLI exposes all these options:

```bash
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- \
  grade ReferencePackage SubmissionPackage \
  --student-id s123 \
  --report s123-feedback.md \
  --html s123-feedback.html \
  --gradescope results.json \
  --csv marks.csv \
  --csv-format canvas \
  --test-timeout 120 \
  --ref-timeout 30
```

## Assignment template library

`examples/` includes ready-to-use reference packages spanning different Julia
teaching domains:

| Example | Topic | Key concepts |
|---|---|---|
| `SortingAssignment` | Algorithms | in-place sort, forbidden packages |
| `RecursiveAssignment` | Recursion | Fibonacci, property checks |
| `ReferenceOracleAssignment` | Reference tests | oracle comparison |
| `StringProcessingAssignment` | String processing | `Dict`, `split`, word frequencies |
| `NumericalMethodsAssignment` | Numerical methods | bisection root-finding, convergence |
| `ConfiguredAssignment` | Config file workflow | `.inc` config, name normalization |
| `ThinAssignment` | Minimal template | bare-minimum structure |

Each example has a complete `src/`, `test/`, `SkeletonizePackage.inc`,
`GRADING_PLAN.md`, and `student_notes.md`. Use any as a starting point:

```julia
cp -r examples/StringProcessingAssignment MyNewAssignment
# then edit Project.toml, src/, test/, student_notes.md
validate_reference_package("MyNewAssignment"; io=stdout, run_tests=true)
```

## VS Code snippets

Copy `.vscode/skeletonize.code-snippets` into your own `.vscode/` folder (or
your global snippets file) to get tab-completable annotation snippets in Julia
files. Available prefixes: `sol`, `scaff`, `stest`, `htest`, `marks`, `areqs`,
`req`, `forb`, `rtest`.

## Property checks

`@require` and `@forbid` checks (`exported`, `calls`, `loop`, `imports`, etc.)
are grading metadata. They run on the source text of the submission with
comments and string literals pre-stripped, preventing false positives from
keywords that appear only in comments or string values.

## Current status

This is still an early package. Validation checks for blocking transformation
errors and teaching-design warnings, and can warn when reference behavioral
tests fail. Property checks use comment/string-stripped source text to avoid
false positives. The transformer remains conservative: annotation macros must
appear on their own line.

## AI use disclosure

This package has been developed with assistance from multiple AI coding agents:

- **Anthropic Claude Sonnet 4.6** (`claude-sonnet-4-6`) — used extensively for
  code review, refactoring, feature implementation (Gradescope integration, LMS
  CSV export, timeout handling, HTML reports, noise-stripped property checks),
  architecture documentation, test writing, and CHANGELOG maintenance.
- **OpenAI Codex** — used for initial documentation, tests, project scaffolding,
  grading continuation, diagnostics, regression coverage, and the grading
  documentation and generated-guidance audit.

Human review remains responsible for correctness, package design, and release
decisions. AI-generated code has been reviewed and tested before inclusion.
