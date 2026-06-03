using JET
using SkeletonizePackage
using Test

if !(VERSION.major == 1 && VERSION.minor == 12)
    error("JET checks are only supported in this project on Julia 1.12.x; got Julia $VERSION")
end

@testset "JET static analysis" begin
    JET.test_package(SkeletonizePackage; target_modules=(SkeletonizePackage,))
end
