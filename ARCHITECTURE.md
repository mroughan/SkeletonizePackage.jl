# Architecture

`SkeletonizePackage.jl` operates on Julia packages used for teaching. The core
idea is that a teacher writes a complete reference package and annotates which
parts are for students, which parts are teacher-only, and which parts describe
the rubric. The tool then creates a student skeleton package and later grades a
student submission package against the reference, rubric, public tests, hidden
tests, and declared requirements.

The names used throughout the package are deliberately explicit:

- **Reference package**: the teacher-owned package containing complete solutions,
  hidden tests, public tests, requirements, and rubric metadata.
- **Skeleton package**: the generated student-facing package. It contains
  scaffolding code, public tests, student instructions, rubric information, and
  the configured `AGENTS.md` policy.
- **Submission package**: the student's completed package, derived from the
  skeleton.

The skeleton should be its own rubric. A student should be able to read the
skeleton package, visible tests, requirements, and rubric files and understand
how their work will be assessed, even though some grading tests may remain
hidden.

## Pipeline

```text
Step 0: create assignment setup
    create_assignment(...) or the init CLI command
        |
        v
Step 1: edit the teacher reference package
    reference source + tests + docs + SkeletonizePackage.inc
        |
        v
Step 2: validate the reference package
    annotation checks + syntax checks + skeleton-design warnings
        |
        v
Step 3: generate the student skeleton package
    remove teacher-only code, keep scaffolding and public material
        |
        v
Step 4: student completes the skeleton
    skeleton package -> submission package
        |
        v
Step 5: grade the submission
    public tests + hidden tests + reference tests + requirements
        |
        v
Step 6: write reports
    student feedback report + one-row CSV marks summary
```

At the package level, the same flow can be read as:

```text
teacher setup
    |
    v
REFERENCE package
    |
    |  validate_reference_package(...)
    |  generate_skeleton_package(...)
    v
SKELETON package
    |
    |  student edits and submits
    v
SUBMISSION package
    |
    |  grade_submission(...)
    v
student feedback report + marks CSV row
```

## Step 0 Setup

`create_assignment(...)` creates a basic teacher workspace. The generated
workspace is intentionally small but complete enough to edit:

- a Julia package with example source and test files,
- a `SkeletonizePackage.inc` configuration file using the INCspec INI-style
  metadata format read and written through `IncCSV.jl`,
- initial documentation for students and teachers,
- examples of `@solution`, `@scaffolding`, `@student_test`, `@hidden_test`,
  `@marks`, requirements, and reference tests,
- a teacher checklist and grading plan.

This step is a convenience layer. Teachers may also create the reference package
manually, provided the same annotations and configuration conventions are used.

## Reference Package

The reference package is the teacher's source of truth. It should compile and
pass its own tests before a skeleton is generated. It contains ordinary Julia
code plus a small annotation language.

```julia
@solution begin
    # teacher-only implementation
end

@scaffolding begin
    # student-facing placeholder or partial implementation
end

@student_test begin
    # visible public tests
end

@hidden_test begin
    # teacher-only grading tests
end
```

Rubric metadata and code properties can be declared beside tests or inside an
assignment requirements block:

```julia
@hidden_test begin
    @marks 2 "handles empty inputs" id="empty-inputs"
    @test mysort(Int[]) == Int[]
end

@assignment_requirements begin
    @require exported(mysort) marks=1 id="interface-export"
    @forbid imports(SortingAlgorithms) zero_marks=true
    @reference_test mysort generator=[[3, 2, 1], Int[]]
end
```

The `zero_marks=true` keyword is reserved for fatal policy failures. For
example, using a forbidden package that bypasses the point of the assignment can
make all other marks irrelevant.

## Validation

`validate_reference_package(...)` checks the reference package before generation.
The validator is intentionally conservative and text-oriented rather than a full
Julia reformatter. It checks for:

- supported annotation names,
- balanced block-style annotations,
- generated Julia syntax after annotation stripping,
- missing public or hidden tests,
- solution blocks without nearby scaffolding where a prompt would be expected,
- scaffolding blocks without an obvious TODO, placeholder, or partial
  implementation.

Validation produces structured issues so the CLI and documentation can show
teacher-facing warnings without blocking generation unnecessarily.

## Skeleton Generation

`generate_skeleton_package(...)` transforms the reference package into the
student skeleton package.

For student-mode output:

- `@solution` bodies are removed,
- `@scaffolding` bodies are kept,
- `@student_test` bodies are kept,
- `@hidden_test` bodies are removed,
- rubric metadata is extracted into `RUBRIC.md`,
- student instructions and configured supporting documents are copied,
- `AGENTS.md` is generated from the configured AI-use policy.

The `AGENTS.md` policy has three modes:

- `forbidden`: AI agents are explicitly forbidden.
- `recorded`: AI agent use is allowed only with a record of actions.
- `allowed`: AI agent use is allowed under the teacher's policy text.

The document cannot prevent misuse by itself, but it makes the permitted policy
explicit in the distributed skeleton.

## Submission And Grading

A student completes the skeleton package and submits it as the submission
package. Grading compares the submission against the assignment contract, not
against a byte-for-byte copy of the reference implementation.

`grade_submission(...)` can run:

- public tests that students saw,
- hidden tests retained by the teacher,
- reference tests that compare submission outputs with fully qualified reference
  functions,
- simple requirement checks from `@require` and `@forbid`,
- rubric-linked marks grouped by visibility (`public` and `hidden`) and totals,
- fatal `zero_marks=true` checks.

Reference tests are useful when the teacher wants hidden tests to ask "does the
student implementation behave like the reference implementation for this input?"
without exposing the reference implementation in the skeleton.

## Reports

### Execution And Scoring

Behavioral test execution and scoring are separate. A child runner uses Julia's
`Test.AbstractTestSet` interface to record assertions without throwing on the
first failure. Julia's parsed expressions wrap `@student_test` and `@hidden_test`
blocks in recorded testsets; ordinary nested testsets inherit the recorder.
Rubric source locations connect executed `@marks` statements to their test
groups, including groups in included files and groups with duplicate names.
This does not require an assignment package to load the examiner's version of
SkeletonizePackage to provide the recorder.

All independent groups are attempted after assertion failures or exceptions
inside a group. An exception outside an assertion stops the remainder of that
group. A setup/import failure, explicit exit, or timeout may prevent later groups
from running. Atomic TOML snapshots preserve observed outcomes before such
interruptions; unfinished groups and unreached criteria are not called failures
of assertions that never ran. Explicit foreign testset types are unsupported and
reported as an error rather than silently discarded.

The existing scoring default remains conservative: all ordinary behavioral
marks require an overall passing behavioral run. Property points are independent.
`zero_on_failure=true` additionally withholds property points after a behavioral
failure. Fatal property gates still zero the assignment. Neither scoring policy
changes the recorded pass/fail outcomes, including `CriterionResult.passed`.
Per-group outcomes do not imply automatic partial-credit scoring.
Oracle annotations are separate metadata, not assertions within their enclosing
groups. Empty or skipped-only groups do not earn ordinary behavioral marks.

The child uses the submission project plus the examiner's active project as
fallback test tooling, with startup files disabled. No automatic dependency
installation or submission edits occur. Brief diagnostics distinguish failed
assertions, dependency/loading problems, test exceptions, reference-oracle
problems, and interrupted execution. Reports retain the underlying exception
and source location. These categories describe evidence, not certain attribution
of fault to a student. Missing dependencies require examiner review before marks
are finalized.

The implementation follows Julia's documented custom testset interface; see
`references/grading/README.md` and its archived upstream documentation.

### Output Formats

Grading returns structured results and supports four output formats:

- Markdown and self-contained HTML feedback, explaining test-group outcomes
  separately from criterion scores;
- Gradescope JSON containing per-criterion scores and messages;
- a compact marks CSV row suitable for concatenating across many students, with
  category totals and an assignment total.

The report is pedagogical. The CSV row is administrative. Diagnostic reports
can contain private assertion expressions, inputs, and source locations; the
examiner must review them before sharing them with students. For status fields,
failure categories, and remediation, see [Grading and Diagnostics](docs/src/grading.md).

## Configuration

Configuration files use the INI-style metadata block defined by
[`mroughan/INCspec`](https://github.com/mroughan/INCspec) and the reader/writer
library in [`mroughan/IncCSV.jl`](https://github.com/mroughan/IncCSV.jl).

Example:

```text
---
[assignment]
reference_path = "."
skeleton_path = "../SortingAssignmentStudent"
mode = "student"
force = false
validate = true
instructions_path = "student_notes.md"
ai_policy = "recorded"
copy_paths = "Project.toml, SkeletonizePackage.inc, src, test, data"
---
config
assignment
```

Paths are relative to the configuration file's directory. This config controls
generation, not grading. Grading options such as `zero_on_failure`, timeouts,
and output paths are Julia keywords or CLI flags.

## Design Constraints

1. The package should use a small, readable annotation language rather than
   trying to become a complete Julia parser or formatter.
2. Hidden code should be removed by transforming block annotations, not by
   deleting arbitrary line ranges that may leave broken syntax.
3. Generated skeleton packages should remain ordinary Julia packages that
   students can read, test, and edit without special tooling.
4. Hidden tests and reference tests should assess behavior and interface
   contracts, not require the submission to be textually identical to the
   reference implementation.
5. The visible skeleton, `RUBRIC.md`, requirements, and public tests should make
   the grading contract clear.

## Security Model

`SkeletonizePackage.jl` is designed for classroom use where both the teacher and
students are trusted participants in an academic setting. It is not designed for
running untrusted code submitted by anonymous users over the internet.

### Execution isolation

Reference tests and submission tests run in **separate Julia processes** spawned via
`Base.julia_cmd()`. This means:

- The grader's own module state is never contaminated by student code.
- Module-name collisions between the reference package and the submission package are
  avoided because each process only loads one of them.
- A student submission that throws an uncaught exception, calls `exit()`, or enters an
  infinite loop affects only its own process; the grader process waits and reads the
  process exit code.

The behavioral runner includes the teacher's tests with expression instrumentation;
their imports load the submitted package in the child environment. Reference-oracle
probes use `include_string` in separate children. Student code is not evaluated in
the grader's own session. Children have the grader's file-system permissions and
can read and write files: process separation is not an OS security sandbox.

### Serialization

Behavioral results use atomic TOML snapshots in temporary files so completed
observations survive interrupted execution. Oracle probes use Julia's
`Serialization` module. Serialized results are not safe to deserialize from
untrusted producers; starting a child process does not make malicious student
code trustworthy. Neither format establishes a security boundary. Use external
OS isolation when the classroom trust assumptions do not hold.

### Threat model

The package assumes:
- The teacher's reference package is trusted.
- The student's submission package is written by a registered student (not an anonymous
  attacker) and will be run with the same OS-level permissions as the grader.
- Grading happens on a machine or CI environment controlled by the teacher, not on a
  shared public server.

Scenarios explicitly **out of scope**:
- Online judge / competitive programming style sandboxing.
- Preventing a malicious student from deleting files or consuming excessive CPU/memory
  during grading (use OS-level resource limits if needed).
- Protecting hidden test content from a student who has OS-level read access to the
  grader machine.

## Current Components

- `annotations.jl`: annotation macros and source transformation.
- `config.jl`: INCspec/IncCSV-backed assignment configuration.
- `generation.jl`: reference-to-skeleton package generation.
- `grading.jl`: test execution, rubric scoring, feedback reports, and CSV rows.
- `grading_runner.jl`: child-process test recorder, annotation instrumentation,
  and incremental TOML result snapshots.
- `properties.jl`: simple `@require` and `@forbid` property checks.
- `rubric.jl`: rubric extraction and rendering.
- `templates.jl`: Step 0 assignment setup templates.
- `validation.jl`: reference package validation.
- `cli.jl`: command-line entry points.
