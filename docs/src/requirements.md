# Requirements

`@marks` describes how many marks a behaviour is worth. `@require` and
`@forbid` describe code properties that are not always captured by example
tests. Put them near tests, or group them in an `@assignment_requirements`
block:

```julia
@assignment_requirements begin
    @require exported(fib)
    @require signature(fib, 1) marks=1 "has the required one-argument interface"
    @require docstring(fib) marks=1 "documents the public function"
    @require comments(min=2)
    @require deterministic(fib)

    @forbid calls(fib, factorial)
    @forbid imports(DataFrames) zero_marks=true "does not use a forbidden shortcut package"

    @reference_test fib generator=1:30
end
```

The generated skeleton package keeps these checks in its visible tests when they
are in student-visible code. It also records them in `RUBRIC.md`, including
requirements that appear inside hidden test blocks.

## Marks and Zeroing Conditions

Required and forbidden properties can carry their own marks:

```julia
@assignment_requirements begin
    @require docstring(fib) marks=1 "documents fib"
    @forbid calls(fib, factorial) marks=2 "implements fib directly"
end
```

Those marks are included in the generated `RUBRIC.md` and in the grading CSV.
They are awarded only when the property passes.

A property can also be a whole-assignment gate:

```julia
@assignment_requirements begin
    @forbid imports(DataFrames) zero_marks=true "does not use a package that solves the task"
end
```

If this property fails during grading, the student's total is set to zero and
the feedback report notes that the assignment was zeroed. This is useful for
forbidden shortcuts that defeat the point of an exercise.

## Function and Interface Properties

Supported interface checks include:

```julia
@require exported(mysort)
@require exists(mysort)
@require signature(mysort, 1)
@require docstring(mysort)
@require deterministic(mysort)
```

`exported(name)` checks for an `export` statement. `exists(name)` and
`signature(name, arity)` inspect source files under `src/`. `docstring(name)`
looks for a triple-quoted docstring immediately before the function.
`deterministic(name)` calls the function more than once on small integer sample
inputs and checks that repeated calls return the same result.

## Structural Properties

Supported structural checks include:

```julia
@require nested_loop_depth(max=1)
@forbid recursive(mysort)
@forbid loop(mysort)
```

These are deliberately lightweight source checks. They are useful for simple
teaching constraints, not for proving semantic properties of arbitrary Julia
programs.

## Forbidden Shortcuts

Supported shortcut checks include:

```julia
@forbid calls(mysort, sort)
@forbid imports(DataFrames)
@forbid uses(mysort, "*")
```

`calls(function, callee)` searches the named function body. `calls(callee)`
searches all source. `imports(name)` searches `using` and `import` lines.
`uses(function, operator)` searches the function body for an operator token.

## Style and Size

Supported style checks include:

```julia
@require comments(min=3)
@require lines_of_code(max=80)
```

These checks are intentionally simple and easy to explain to students.

## Reference Tests

`@reference_test` compares a submitted function with the teacher's reference
implementation during grading:

```julia
@reference_test fib generator=1:30
```

The grading harness runs the reference package and submission package in
separate Julia processes. That avoids module-name collisions when both packages
have the same module name. Each generated input is passed to the named function
on both sides and the rendered outputs are compared.

Tuple inputs are splatted, so this tests a two-argument function:

```julia
@reference_test distance generator=[((0, 0), (3, 4)), ((1, 1), (1, 5))]
```

The checked-in `examples/ReferenceOracleAssignment` package shows the pattern:

```julia
@hidden_test begin
    @marks 3 "matches the reference implementation on generated inputs"
    @reference_test clamp01 generator=[-2, -0.5, 0, 0.25, 1, 2]
end
```

When `grade_submission` runs, the student feedback report includes a
`Reference Tests` section with one entry for each generated input.
