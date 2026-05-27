using SkeletonPackages
using Test

@testset "strip_teacher_annotations" begin
    src = """
module Demo

function f(x)
    @solution begin
        return x + 1
    end
    @starter begin
        error("TODO")
    end
end

@student_test begin
    @test f(1) == 2
end

@hidden_test begin
    @test f(100) == 101
end

end
"""

    student = strip_teacher_annotations(src; mode=:student)
    @test occursin("error(\"TODO\")", student)
    @test !occursin("return x + 1", student)
    @test occursin("@test f(1) == 2", student)
    @test !occursin("@test f(100) == 101", student)

    teacher = strip_teacher_annotations(src; mode=:teacher)
    @test occursin("return x + 1", teacher)
    @test !occursin("error(\"TODO\")", teacher)
    @test occursin("@test f(100) == 101", teacher)

    @test_throws ArgumentError strip_teacher_annotations(src; mode=:invalid)
    @test_throws ArgumentError strip_teacher_annotations("@solution begin\nx = 1"; mode=:student)
end

@testset "strip_teacher_annotations preserves ordinary code" begin
    src = """
function g(xs)
    y = begin
        sum(xs)
    end
    @starter begin
        return y
    end
end
"""

    student = strip_teacher_annotations(src)
    @test occursin("y = begin", student)
    @test occursin("sum(xs)", student)
    @test occursin("return y", student)
end

@testset "macro runtime behaviour" begin
    @test (@solution begin 1 + 1 end) == 2
    @test (@starter begin error("starter should not run in teacher package") end) === nothing
    @test (@student_test begin 3 + 4 end) == 7
    @test (@hidden_test begin 5 + 6 end) == 11
end

@testset "generate_student_package" begin
    tmp = mktempdir()
    src = joinpath(tmp, "X")
    dst = joinpath(tmp, "Y")
    mkpath(joinpath(src, "src"))
    write(joinpath(src, "Project.toml"), """
name = "Demo"
uuid = "7ab20f4c-9a1d-43a5-8e9d-54c7a5cb8eaa"
version = "0.1.0"
""")
    write(joinpath(src, "src", "Demo.jl"), """
module Demo
using SkeletonPackages
f(x) = begin
    @solution begin
        x + 1
    end
    @starter begin
        error("TODO")
    end
end
end
""")
    generate_student_package(src, dst; io=nothing)
    @test isfile(joinpath(dst, "src", "Demo.jl"))
    @test isfile(joinpath(dst, "STUDENT_INSTRUCTIONS.md"))
    text = read(joinpath(dst, "src", "Demo.jl"), String)
    @test occursin("error(\"TODO\")", text)
    @test !occursin("x + 1", text)
    instructions = read(joinpath(dst, "STUDENT_INSTRUCTIONS.md"), String)
    @test occursin("julia --project=.", instructions)
    @test occursin("Pkg.instantiate()", instructions)
    @test occursin("Pkg.test()", instructions)
    @test occursin("src/", instructions)

    teacher_dst = joinpath(tmp, "Teacher")
    generate_student_package(src, teacher_dst; mode=:teacher, io=nothing)
    teacher_text = read(joinpath(teacher_dst, "src", "Demo.jl"), String)
    @test occursin("x + 1", teacher_text)
    @test !occursin("error(\"TODO\")", teacher_text)

    @test_throws ArgumentError generate_student_package(src, teacher_dst; io=nothing)
    generate_student_package(src, teacher_dst; force=true, io=nothing)
end

@testset "validation" begin
    tmp = mktempdir()
    src = joinpath(tmp, "Bad")
    mkpath(joinpath(src, "src"))
    write(joinpath(src, "Project.toml"), """
name = "Bad"
uuid = "7ab20f4c-9a1d-43a5-8e9d-54c7a5cb8eaa"
version = "0.1.0"
""")
    write(joinpath(src, "src", "Bad.jl"), """
module Bad
using SkeletonPackages
f() = @solution begin
    1
end
@hidden begin
    2
end
end
""")

    report = validate_teacher_package(src)
    @test !isvalid(report)
    rendered = sprint(show, report)
    @test occursin("unsupported", rendered)
    @test occursin("missing test directory", rendered)
    @test occursin("no @student_test", rendered)
end

@testset "assignment config and template" begin
    tmp = mktempdir()
    assignment = create_assignment(joinpath(tmp, "DemoAssignment"))
    @test isfile(joinpath(assignment, "Project.toml"))
    @test isfile(joinpath(assignment, "SkeletonPackages.toml"))

    report = validate_teacher_package(assignment)
    @test isvalid(report)

    config = SkeletonPackages.read_assignment_config(joinpath(assignment, "SkeletonPackages.toml"))
    @test config.mode == :student
    generated = generate_student_package(config; io=nothing)
    @test isfile(joinpath(generated, "src", "DemoAssignment.jl"))
    @test isfile(joinpath(generated, "STUDENT_INSTRUCTIONS.md"))
    text = read(joinpath(generated, "src", "DemoAssignment.jl"), String)
    @test occursin("TODO", text)
    @test !occursin("return 42", text)
end

@testset "grade result" begin
    result = SkeletonPackages.GradeResult(true, 0, "ok", "")
    @test isvalid(result)
    @test occursin("passed", sprint(show, result))
end

@testset "quality checks" begin
    try
        @eval import Aqua
        Aqua.test_all(SkeletonPackages; ambiguities = false)
    catch err
        if err isa ArgumentError || err isa LoadError
            @warn "Aqua is unavailable; skipping Aqua checks" exception = (err, catch_backtrace())
        else
            rethrow()
        end
    end

    try
        @eval import JET
        JET.test_package(SkeletonPackages; target_modules = (SkeletonPackages,))
    catch err
        if err isa ArgumentError || err isa LoadError
            @warn "JET is unavailable; skipping JET checks" exception = (err, catch_backtrace())
        else
            rethrow()
        end
    end
end
