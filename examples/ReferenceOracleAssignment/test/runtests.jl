using ReferenceOracleAssignment
using SkeletonizePackage
using Test

@assignment_requirements begin
    @require exported(clamp01)
    @require signature(clamp01, 1) marks=1 "keeps the required one-argument interface"
    @require docstring(clamp01) marks=1 "documents clamp01"
    @forbid imports(DataFrames) zero_marks=true "does not use a shortcut package"
end

@student_test begin
    @marks 1 "leaves an in-range value unchanged"
    @test clamp01(0.4) == 0.4
end

@hidden_test begin
    @marks 3 "matches the reference implementation on generated inputs"
    @reference_test clamp01 generator=[-2, -0.5, 0, 0.25, 1, 2]
end
