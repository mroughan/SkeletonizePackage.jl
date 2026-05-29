# Requirements

`@marks` describes how many marks a behaviour is worth. `@require` and
`@forbid` describe code properties that are not always captured by example
tests. Put them near tests, or group them in an `@assignment_requirements`
block:

```julia
@assignment_requirements begin
    @require exported(fib)
    @require signature(fib, 1)
    @require docstring(fib)
    @require comments(min=2)
    @require deterministic(fib)

    @forbid calls(fib, factorial)
    @forbid imports(DataFrames)

    @reference_test fib generator=1:30
end
```

The generated student package keeps these checks in its visible tests when they
are in student-visible code. It also records them in `RUBRIC.md`, including
requirements that appear inside hidden test blocks.

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

`@reference_test` currently records reference-test intent in the generated
rubric:

```julia
@reference_test fib generator=1:30
```

Execution of reference tests belongs in the grading harness, where both the
teacher reference implementation and student submission are available.
