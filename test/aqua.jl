using Aqua
using SkeletonizePackage
using Test

@testset "Aqua quality checks" begin
    Aqua.test_all(SkeletonizePackage; ambiguities=false)
end
