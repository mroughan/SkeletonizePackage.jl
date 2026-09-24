# Grading and Diagnostics

`grade_submission(reference, submission)` runs the teacher's original
`test/runtests.jl` against the submitted package, not the student's test files.
It then evaluates reference-oracle comparisons and source-property requirements.
Keep the reference unchanged during marking and try known-good and known-bad
submissions before grading a class.

## Run the Grader

From an examiner environment containing SkeletonizePackage and the test tooling:

```julia
using SkeletonizePackage

result = grade_submission("ReferencePackage", "SubmissionPackage";
    student_id="s123",
    zero_on_failure=true,
    report_path="s123-feedback.md",
    html_path="s123-feedback.html",
    gradescope_path="s123-results.json",
    csv_path="marks.csv",
)
result.total_awarded
result.failure_category
result.test_results
```

The equivalent CLI invocation is:

```bash
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- \
  grade ReferencePackage SubmissionPackage --student-id s123 \
  --zero-on-failure --report s123-feedback.md --html s123-feedback.html \
  --gradescope s123-results.json --csv marks.csv
```

The CLI returns `0` for a passing grade, `2` for a completed grading operation
whose result did not pass, and `1` for usage or caught command errors. Saved
reports do not suppress brief failure diagnostics on stderr. Julia callers can
redirect these with `io=...` or disable them with `io=nothing`.

## Outcomes and Marks

| Policy | Ordinary `@marks` points | Property points |
|:--|:--|:--|
| Default | Require an overall passing behavioral run, including oracle comparisons, and a passing marked group | Awarded for passing properties independently of behavioral failures |
| `zero_on_failure=true` | All withheld after a behavioral failure | Also withheld after a behavioral failure |
| Failed `zero_marks=true` property gate | All withheld | All withheld |

Passing groups remain visible even with a total of zero. In `criterion_results`,
`passed` records the observed outcome and `awarded` records the score; do not
infer one from the other. Per-group reporting does **not** enable partial credit.
A group with no evaluated assertions, including a skipped-only group, receives
no behavioral marks. `@reference_test` is metadata evaluated separately; it does
not count as an assertion inside its group or award points itself. Place
meaningful `@test` assertions alongside marked reference comparisons.

`zero_on_failure` is a grading keyword or CLI flag, not an INC generation
configuration setting. Record the chosen policy in the grading plan and
communicate it to students before assessment.

### Whole-Assignment Zero Notice

A triggered `zero_marks=true` gate or `zero_on_failure=true` policy produces an
**ASSIGNMENT ZEROED** notice at the top of the report. It states that all marks
are withheld and names the checks that triggered zeroing. Markdown, HTML,
Gradescope, and the brief examiner diagnostic carry the warning; passing
outcomes remain visible below it.

For fatal properties, the location identifies the rule declaration in the
teacher's reference package, not an inferred offending student line. For
assertion failures, it gives the recorded test group, Julia's file/line location,
and the initial failure detail. Oracle failures identify the function, input,
and matching declaration locations. When no assertion location is available,
the notice says so rather than inventing one.

The report lists all recorded zeroing causes. The brief summary shows the first
three and indicates additional causes. `failure_message` includes the warning,
while `failure_category` retains the underlying diagnosis; zeroing due to a
missing dependency is still an environment problem, not an incorrect-answer
judgment. An ordinary zero score without a triggered whole-assignment policy
does not receive this notice.

## What Continues Running

A failed `@test` is recorded and later assertions continue. An exception outside
an assertion stops the remainder of its group, but later independent groups are
attempted. Use separate `@student_test` or `@hidden_test` blocks for independent
criteria, ideally one `@marks` entry per block.

Top-level imports or setup errors, explicit process exits, and timeouts can
prevent later groups from running. Snapshots preserve already observed results;
unexecuted assertions are not called failed assertions. Ordinary nested
`@testset`s inherit the recorder, including in normally included test files.
Explicit third-party custom testset types are unsupported and produce an error.
This continuation behavior belongs to the grader; local `Pkg.test()` still uses
Julia's usual testset behavior.

`result.test_results` contains a root summary followed by recorded groups. Each
entry has `name`, `status`, `passed`, `failed`, `errored`, `broken`, `details`, and
`marks` (executed rubric source locations). Counts include descendants, so do
not sum the root and group counts together.

| Status | Meaning |
|:--|:--|
| `:passed` | Evaluated assertions passed |
| `:failed` | At least one assertion failed |
| `:error` | An exception was recorded |
| `:not_run` | No assertions were evaluated; may include skipped assertions |
| `:incomplete` | Execution did not finish this group |

Unreached rubric criteria appear in `criterion_results`, even when no group was
created for them. `broken` counts expected-broken and skipped assertions. An
errored or incomplete group can have both completed and unexecuted assertions.

## Diagnose a Failure

The brief diagnostic names the student, a failure category, counts and marks
when available, and an initial exception detail. Use the report's Test Output
section, `stdout`, `stderr`, and structured results for context.

| `failure_category` | What to inspect |
|:--|:--|
| `:none` | No classified failure |
| `:test_failure` | Assertion, expected/actual values, and assignment contract |
| `:test_error` | Exception in a test or setup; check both the test and submission |
| `:environment_failure` | Missing, uninstalled, or undeclared dependency |
| `:load_failure` | Parsing, loading, or precompilation error and its underlying cause |
| `:execution_failure` | Process launch, invalid result data, abrupt exit, or no evaluated assertions |
| `:reference_failure` | Teacher reference-oracle execution failure |
| `:property_failure` | Required or forbidden source-property checks |
| `:timeout` | Submission test process exceeded its time limit |
| `:zero_gate` | A fatal property policy zeroed the assignment |

A category summarizes evidence, not responsibility. Multiple problems may occur;
individual results give more detail. A zero score caused by a missing package
does not establish that every hidden assertion is wrong. A failed assertion can
also expose a faulty test.

### Environment Checklist

1. Read the underlying exception and identify which package/project failed.
2. Check the submission's `Project.toml`, available `Manifest.toml`, Julia version,
   and dependency declarations. Preserve the original submission before repairs.
3. Instantiate the affected environment deliberately, outside grading. For
   example, `julia --project=SubmissionPackage -e 'using Pkg; Pkg.instantiate()'`
   can install dependencies and change a manifest; retain a record of repairs.
4. Check that the examiner environment supplies the teacher's test dependencies.
   If SkeletonizePackage fails to precompile, inspect its underlying error
   instead of interpreting that as a student assertion failure.
5. Retry a known-good submission in the same environment, then rerun the affected
   submission before finalizing marks.

The behavioral child uses the submission project first and the examiner's
active project as fallback tooling, with startup files disabled. The grader does
not automatically install packages or edit the submission. Fallback tooling
does not repair an undeclared dependency inside the student's package.

`test_timeout_seconds=120` (`--test-timeout`) limits the behavioral child;
`reference_timeout_seconds=30` (`--ref-timeout`) limits each reference subprocess.
Use `0` to disable either limit. These are not a total wall-clock grading limit.
Invalid paths or option values can raise `ArgumentError`; report-file write
errors can also propagate rather than returning a `GradeResult`.

## Reports and Exports

Markdown, self-contained HTML, Gradescope JSON, and CSV are available on the
result even without output paths. Markdown and HTML contain group outcomes
separately from criterion scores. Gradescope contains per-criterion scores and
messages. CSV summarizes awarded marks, not assertion counts.

CSV appends by default. Use `append_csv=false` (`--replace-csv`) to overwrite.
`csv_format=:canvas`, `:moodle`, or `:blackboard` changes the student-ID column
name; it does not create a complete LMS course import schema. The default is
`:default`. See [`grade_submission`](@ref) for all keyword options.

Review reports before distribution: exception messages, assertion expressions,
inputs, and source locations can reveal hidden-test details. Generated rubrics
omit private test bodies, but diagnostic reports are not automatically redacted.
Separate Julia processes prevent module-state collisions, not malicious code
access to files. Run submissions only in an appropriately isolated environment.
