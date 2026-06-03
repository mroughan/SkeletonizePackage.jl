# Numerical Methods Assignment

In this assignment you will implement the bisection root-finding algorithm.

## Task

Implement `bisect(f, a, b; tol=1e-8, maxiter=100)` in
`src/NumericalMethodsAssignment.jl`.

**`bisect(f, a, b)`** should find a root of `f` in the interval `[a, b]` using
the bisection method:

1. Check that `f(a)` and `f(b)` have opposite signs; throw `ArgumentError` if not.
2. Repeatedly halve the interval by evaluating `f` at the midpoint.
3. Keep the half that contains a sign change.
4. Stop when the interval width is less than `tol`, or after `maxiter` iterations.
5. Return the midpoint of the final bracket as a `Float64`.

## Background

The bisection method guarantees convergence when `f` is continuous and `f(a)` and
`f(b)` have opposite signs. It converges linearly: each iteration halves the error.

## Hints

- `sign(x)` returns `-1`, `0`, or `1`.
- The midpoint of `[a, b]` is `(a + b) / 2`.
- After each iteration, update either `a` or `b` (and the corresponding function value).

## Submission

Run the tests with `julia --project=. -e 'using Pkg; Pkg.test()'` before submitting.
