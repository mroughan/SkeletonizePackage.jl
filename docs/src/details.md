# Additional Details

## Implementation Philosophy

`SkeletonizePackage.jl` does not try to be a full Julia parser or reformatter.
Instead, it defines a small annotation language that is easy to recognize and
transform. That keeps generated packages readable and avoids surprising edits
outside marked regions.

The validation step checks annotated files before and after transformation so
broken generated Julia source is caught early. It also checks package/module
wiring and reports teaching-design warnings, such as an annotated source file
that is not included or a solution block without nearby scaffolding code.

The broader grading philosophy is behavioural rather than textual: submission
packages should be checked using public tests, hidden tests, reference
comparisons, interface checks, and documentation examples, not by comparing
their source code directly with the reference solution.

## Command Line

The package exposes a small CLI-style entry point:

```bash
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- validate examples/SortingAssignment
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- generate examples/SortingAssignment SortingAssignmentStudent --force --ai-policy recorded
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- generate --config examples/ConfiguredAssignment/SkeletonizePackage.inc --force
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- grade examples/SortingAssignment StudentSubmission --report feedback.md --csv marks.csv
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- init MyAssignment --ai-policy recorded
```

## Annotation Contract

The transformer is line-oriented. Put each annotation opener on its own line,
using exactly one of the supported forms:

```julia
@solution begin
    # teacher-only code
end
```

Supported annotations are `@solution`, `@scaffolding`, `@student_test`, and
`@hidden_test`. Rubric and grading metadata use `@marks`, `@require`, `@forbid`,
`@assignment_requirements`, and `@reference_test`.

The transformer preserves the body of a kept annotation and removes both the
annotation opener and its matching closing `end`. This means the contents of
each block should be valid in the surrounding file after the annotation wrapper
is gone. During package generation, kept Julia test blocks are additionally
wrapped in named `@testset`s.

## Configuration Files

Configuration files use the INC file model: an INI-style metadata block
delimited by `---` lines, followed by a small CSV component. `SkeletonizePackage`
uses `IncCSV.jl` to read and write these files.

Metadata values are strings or integers. Boolean settings such as `force` and
`validate` may be written as `true`/`false`, `yes`/`no`, or `1`/`0`.

The `ai_policy` setting may be `forbidden`, `recorded`, or `allowed`. It
controls the generated `AGENTS.md` file in the student skeleton. This file is
not a technical security mechanism; it is an explicit instruction and audit
record that makes the teacher's AI-use rule unambiguous.

`instructions_path` selects exercise-specific Markdown for
`STUDENT_INSTRUCTIONS.md`. If omitted, a root `student_notes.md` is used
automatically when present.

## Rubric Generation

Use `@marks POINTS "description"` inside `@student_test` or `@hidden_test`
blocks to keep rubric information near the tests it describes.

```julia
@student_test begin
    @marks 1 "normalizes a simple name"
    @test normalize_name("Ada") == "ada"
end

@hidden_test begin
    @marks 2 "handles leading and trailing whitespace"
    @test normalize_name("  Grace  ") == "grace"
end
```

`@marks` is a no-op macro at runtime. During generation,
`SkeletonizePackage.jl` extracts those entries into `RUBRIC.md`, split into
public and hidden criteria. This gives students the grading contract without
revealing private test implementations.

Each generated public or teacher-mode test block becomes a named `@testset`,
using the first `@marks` description as its name. Each `@marks` line creates a
rubric criterion, but behavioural marks are currently awarded at whole-test-run
granularity. Prefer one `@marks` line and one coherent behaviour per test block;
split unrelated criteria into separate `@student_test` or `@hidden_test` blocks.

Stable IDs can be supplied with `id="..."` on `@marks`, `@require`, and
`@forbid`. IDs are useful in moderation, appeals, feedback reports, and teacher
grading plans. If an ID is omitted, one is generated from the criterion
metadata.
