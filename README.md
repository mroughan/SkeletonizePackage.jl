# SkeletonPackages.jl

`SkeletonPackages.jl` is a teaching-oriented metapackage for generating student
starter packages from teacher solution packages.

## Quick start

From Julia, generate a student package from the included example:

```julia
using SkeletonPackages

generate_student_package("examples/SortingAssignment", "SortingAssignmentStudent")
```

The generated package keeps starter implementations and public tests, while
removing solution blocks and hidden tests.

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

## Teacher annotations

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

Visible and hidden tests can be marked similarly:

```julia
@student_test begin
    @test mysort([2,1]) == [1,2]
end

@hidden_test begin
    @test mysort([3,1,2]) == [1,2,3]
end
```

Then generate the student version:

```julia
using SkeletonPackages

generate_student_package("SortingAssignment", "SortingAssignmentStudent")
```

## Examples

See `examples/SortingAssignment` for a minimal annotated teacher package. It
contains:

- `@solution` code that runs in the teacher package.
- `@starter` code that appears in the generated student package.
- `@student_test` tests that students can see.
- `@hidden_test` tests that teachers can keep for grading.

## Current status

This is an intentionally small first version. It uses line-oriented transformations
and assumes annotation macros appear on their own lines. Future versions should
replace this with a concrete syntax tree transformation using `JuliaSyntax.jl` or
a similar parser.

## AI use disclosure

This package includes documentation, tests, and project scaffolding that were
drafted or revised with assistance from OpenAI's Codex. Human review remains
responsible for correctness, package design, and release decisions.
