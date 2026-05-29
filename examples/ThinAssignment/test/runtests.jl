using ThinAssignment
using SkeletonPackages
using Test

@assignment_requirements begin
    @require exported(double_it)
    @require exists(double_it)
    @require signature(double_it, 1)
    @require docstring(double_it)
    @forbid imports(DataFrames)
end

@student_test begin
    @marks 1 "double_it doubles a positive integer"
    @test double_it(3) == 6
end

@hidden_test begin
    @marks 1 "double_it handles negative integers"
    @test double_it(-2) == -4
end
