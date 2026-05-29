using SortingAssignment
using Test
using SkeletonPackages

@assignment_requirements begin
    @require exported(mysort)
    @require exists(mysort)
    @require signature(mysort, 1)
    @require docstring(mysort)
    @forbid imports(DataFrames)
    @require nested_loop_depth(max=1)
end

@student_test begin
    @marks 1 "sorts a simple two-element vector"
    @test mysort([2, 1]) == [1, 2]
    @marks 2 "returns sorted values without mutating the input"
    xs = [3, 2, 1]
    @test mysort(xs) == [1, 2, 3]
    @test xs == [3, 2, 1]
end

@hidden_test begin
    @marks 1 "handles a three-element unsorted vector"
    @test mysort([3, 1, 2]) == [1, 2, 3]
    @marks 1 "handles empty vectors"
    @test mysort(Int[]) == Int[]
    @marks 1 "handles repeated values"
    @test mysort([1, 1, 1]) == [1, 1, 1]
    @marks 1 "handles sortable non-numeric values"
    @test mysort(["b", "a"]) == ["a", "b"]
end
