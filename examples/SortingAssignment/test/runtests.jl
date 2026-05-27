using SortingAssignment
using Test
using SkeletonPackages

@student_test begin
    @test mysort([2, 1]) == [1, 2]
    xs = [3, 2, 1]
    @test mysort(xs) == [1, 2, 3]
    @test xs == [3, 2, 1]
end

@hidden_test begin
    @test mysort([3, 1, 2]) == [1, 2, 3]
    @test mysort(Int[]) == Int[]
    @test mysort([1, 1, 1]) == [1, 1, 1]
    @test mysort(["b", "a"]) == ["a", "b"]
end
