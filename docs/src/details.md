# Additional Details

## Implementation Philosophy

`SkeletonPackages.jl` does not try to be a full Julia parser or reformatter.
Instead, it defines a small annotation language that is easy to recognize and
transform. That keeps generated packages readable and avoids surprising edits
outside marked regions.

The validation step checks annotated files before and after transformation so
broken generated Julia source is caught early. It also reports teaching-design
warnings, such as a solution block without nearby starter code.

The broader grading philosophy is behavioural rather than textual: student
submissions should be checked using public tests, hidden tests, reference
comparisons, interface checks, and documentation examples, not by comparing
their source code directly with the teacher solution.

## Command Line

The package exposes a small CLI-style entry point:

```bash
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- validate examples/SortingAssignment
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate examples/SortingAssignment SortingAssignmentStudent --force
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate --config examples/ConfiguredAssignment/SkeletonPackages.inc --force
julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- init MyAssignment
```

## Annotation Contract

The transformer is line-oriented. Put each annotation opener on its own line,
using exactly one of the supported forms:

```julia
@solution begin
    # teacher-only code
end
```

Supported annotations are `@solution`, `@starter`, `@student_test`, and
`@hidden_test`.

The transformer preserves the body of a kept annotation and removes both the
annotation opener and its matching closing `end`. This means the contents of
each block should be valid in the surrounding file after the annotation wrapper
is gone.

## Configuration Files

Configuration files use the INC file model: an INI-style metadata block
delimited by `---` lines, followed by a small CSV component. `SkeletonPackages`
uses `IncCSV.jl` to read and write these files.

Metadata values are strings or integers. Boolean settings such as `force` and
`validate` may be written as `true`/`false`, `yes`/`no`, or `1`/`0`.

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
`SkeletonPackages.jl` extracts those entries into `RUBRIC.md`, split into
public and hidden criteria. This gives students the grading contract without
revealing private test implementations.
