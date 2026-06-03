using NumericalMethodsAssignment
using SkeletonizePackage
using Test

@student_test begin
    @marks 2 "bisect finds root of a linear function" id="public-bisect-linear"
    @test abs(bisect(x -> x - 1.0, 0.0, 2.0) - 1.0) < 1e-6
end

@student_test begin
    @marks 1 "bisect throws on invalid interval" id="public-bisect-error"
    @test_throws ArgumentError bisect(x -> x + 1.0, 0.0, 2.0)
end

@hidden_test begin
    @marks 2 "bisect finds root of a quadratic" id="hidden-bisect-quadratic"
    @test abs(bisect(x -> x^2 - 2, 1.0, 2.0) - sqrt(2)) < 1e-6
end

@hidden_test begin
    @marks 2 "bisect respects tolerance" id="hidden-bisect-tol"
    result = bisect(x -> x - π, 3.0, 4.0; tol=1e-10)
    @test abs(result - π) < 1e-9
end

@hidden_test begin
    @marks 1 "bisect matches reference on generated inputs" id="hidden-bisect-ref"
    # Lambda generator: evaluated in subprocess, repr'd for display only
    @reference_test bisect generator=[(x -> x - 1.5, 0.0, 3.0), (x -> x^2 - 4, 1.0, 3.0)]
end

@assignment_requirements begin
    @require exported(bisect)    marks=1 id="interface-bisect-export"   "exports bisect"
    @require docstring(bisect)   marks=1 id="style-bisect-docstring"    "documents bisect"
    @require loop(bisect)        marks=1 id="impl-bisect-loop"          "uses a loop in bisect"
    @forbid calls(bisect, bisect) zero_marks=true "does not use recursion (bisection is iterative)"
end
