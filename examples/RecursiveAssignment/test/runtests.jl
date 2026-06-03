using RecursiveAssignment
using SkeletonizePackage
using Test

@student_test begin
    @marks 1 "handles the base cases" id="fib-base-cases"
    @test fib(0) == 0
    @test fib(1) == 1
end

@hidden_test begin
    @marks 2 "handles larger recursive inputs" id="fib-larger-inputs"
    @test fib(8) == 21
    @reference_test fib generator=0:10
end

@assignment_requirements begin
    @require recursive(fib) marks=1 id="fib-recursive" "uses recursion"
    @require docstring(fib) marks=1 id="fib-docstring" "documents fib"
    @forbid calls(fib, factorial) zero_marks=true "does not delegate to an unrelated shortcut"
end
