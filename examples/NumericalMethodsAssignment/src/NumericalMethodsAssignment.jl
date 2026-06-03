module NumericalMethodsAssignment

using SkeletonizePackage

export bisect

"""
    bisect(f, a, b; tol=1e-8, maxiter=100) -> Float64

Find a root of `f` in the interval `[a, b]` using the bisection method.
Requires `f(a)` and `f(b)` to have opposite signs (i.e. a sign change must
exist in the interval). Returns the midpoint of the final bracket.

# Example

```julia
julia> abs(bisect(x -> x^2 - 2, 1.0, 2.0) - sqrt(2)) < 1e-6
true

julia> abs(bisect(x -> x - 3.0, 0.0, 5.0) - 3.0) < 1e-6
true
```
"""
function bisect(f, a::Real, b::Real; tol::Real=1e-8, maxiter::Int=100)
    @solution begin
        fa, fb = f(a), f(b)
        sign(fa) == sign(fb) && throw(ArgumentError("f(a) and f(b) must have opposite signs"))
        for _ in 1:maxiter
            mid = (a + b) / 2
            abs(b - a) < tol && return Float64(mid)
            fmid = f(mid)
            if sign(fmid) == sign(fa)
                a = mid; fa = fmid
            else
                b = mid; fb = fmid
            end
        end
        return Float64((a + b) / 2)
    end
    @scaffolding begin
        error("TODO: implement bisect")
    end
end

end
