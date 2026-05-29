using SkeletonPackages
using IncCSV
using Test

_same_path(a, b) = rstrip(abspath(a), ['/', '\\']) == rstrip(abspath(b), ['/', '\\'])
_deterministic_probe(x) = 2x

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
    @marks 1 "public check for f"
    @test f(1) == 2
end

@hidden_test begin
    @marks 2 "hidden check for larger input"
    @test f(100) == 101
end

end
"""

    student = strip_teacher_annotations(src; mode=:student)
    @test occursin("error(\"TODO\")", student)
    @test !occursin("return x + 1", student)
    @test occursin("@test f(1) == 2", student)
    @test !occursin("@test f(100) == 101", student)
    @test occursin("@marks 1 \"public check for f\"", student)

    teacher = strip_teacher_annotations(src; mode=:teacher)
    @test occursin("return x + 1", teacher)
    @test !occursin("error(\"TODO\")", teacher)
    @test occursin("@test f(100) == 101", teacher)
    @test occursin("@marks 2 \"hidden check for larger input\"", teacher)

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
    @test (@marks 1 "runtime no-op") === nothing
end

@testset "assignment requirements macros" begin
    @assignment_requirements begin
        @require exported(generate_student_package)
        @require exists(generate_student_package)
        @require signature(read_assignment_config, 1)
        @require docstring(generate_student_package)
        @require comments(min=0)
        @require lines_of_code(max=5000)
        @require nested_loop_depth(max=4)
        @require deterministic(_deterministic_probe)
        @forbid imports(DataFrames)
        @forbid calls(generate_student_package, factorial)
        @reference_test generate_student_package generator=1:3
    end
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
export f
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
    mkpath(joinpath(src, "test"))
    write(joinpath(src, "test", "runtests.jl"), """
using Demo
using SkeletonPackages
using Test

@student_test begin
    @assignment_requirements begin
        @require exported(f)
        @require exists(f)
        @require signature(f, 1)
        @forbid imports(DataFrames)
    end
    @marks 1 "f handles a public input"
    @test f(1) == 2
end

@hidden_test begin
    @marks 2 "f handles a larger hidden input"
    @test f(100) == 101
end
""")
    custom_notes = joinpath(src, "student_notes.md")
    write(custom_notes, """
# Demo Task

Implement `f`.

@solution begin
Teacher-only reminder.
end

@starter begin
Student-facing hint.
end
""")
    generate_student_package(src, dst; instructions_path=custom_notes, io=nothing)
    @test isfile(joinpath(dst, "src", "Demo.jl"))
    @test isfile(joinpath(dst, "STUDENT_INSTRUCTIONS.md"))
    @test isfile(joinpath(dst, "RUBRIC.md"))
    text = read(joinpath(dst, "src", "Demo.jl"), String)
    @test occursin("error(\"TODO\")", text)
    @test !occursin("x + 1", text)
    instructions = read(joinpath(dst, "STUDENT_INSTRUCTIONS.md"), String)
    @test occursin("julia --project=.", instructions)
    @test occursin("Pkg.instantiate()", instructions)
    @test occursin("Pkg.test()", instructions)
    @test occursin("src/", instructions)
    @test occursin("Exercise-Specific Instructions", instructions)
    @test occursin("Implement `f`.", instructions)
    @test occursin("Student-facing hint.", instructions)
    @test !occursin("Teacher-only reminder.", instructions)
    rubric = read(joinpath(dst, "RUBRIC.md"), String)
    @test occursin("Total: 3 marks", rubric)
    @test occursin("f handles a public input", rubric)
    @test occursin("f handles a larger hidden input", rubric)
    @test occursin("Public Code Properties", rubric)
    @test occursin("must satisfy `exported(f)`", rubric)

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
    config_path = joinpath(assignment, "SkeletonPackages.inc")
    @test isfile(config_path)
    config_file = readinc(config_path)
    @test metadata(config_file)["assignment"]["source_path"] == "."
    @test metadata(config_file)["assignment"]["validate"] == "true"

    report = validate_teacher_package(assignment)
    @test isvalid(report)

    config = SkeletonPackages.read_assignment_config(config_path)
    @test config.mode == :student
    @test config.instructions_path == joinpath(assignment, "student_notes.md")
    generated = generate_student_package(config; io=nothing)
    @test isfile(joinpath(generated, "src", "DemoAssignment.jl"))
    @test isfile(joinpath(generated, "STUDENT_INSTRUCTIONS.md"))
    @test isfile(joinpath(generated, "RUBRIC.md"))
    text = read(joinpath(generated, "src", "DemoAssignment.jl"), String)
    @test occursin("TODO", text)
    @test !occursin("return 42", text)
    instructions = read(joinpath(generated, "STUDENT_INSTRUCTIONS.md"), String)
    @test occursin("Assignment Notes", instructions)
    rubric = read(joinpath(generated, "RUBRIC.md"), String)
    @test occursin("answer returns an integer", rubric)
    @test occursin("answer returns the required value", rubric)
end

@testset "checked-in examples" begin
    examples_root = joinpath(@__DIR__, "..", "examples")
    examples = [
        "ThinAssignment",
        "SortingAssignment",
        "ConfiguredAssignment",
    ]

    tmp = mktempdir()
    for name in examples
        source = joinpath(examples_root, name)
        @testset "$name" begin
            report = validate_teacher_package(source)
            @test isvalid(report)

            config_path = joinpath(source, "SkeletonPackages.inc")
            if isfile(config_path)
                config = SkeletonPackages.read_assignment_config(config_path)
                @test _same_path(config.source_path, source)
                test_config = SkeletonPackages.AssignmentConfig(
                    config.source_path,
                    joinpath(tmp, "$(name)Student"),
                    config.mode,
                    true,
                    config.validate,
                    config.instructions_path,
                )
                generated = generate_student_package(test_config; io=nothing)
            else
                generated = generate_student_package(source, joinpath(tmp, "$(name)Student"); io=nothing)
            end

            @test isfile(joinpath(generated, "Project.toml"))
            generated_source = read(joinpath(generated, "src", "$name.jl"), String)
            @test occursin("TODO", generated_source)
            @test !occursin("return sort", generated_source)
            @test !occursin("return 2x", generated_source)
            @test !occursin("lowercase(strip", generated_source)

            generated_tests = read(joinpath(generated, "test", "runtests.jl"), String)
            @test occursin("@test", generated_tests)
            @test !occursin("@hidden_test", generated_tests)
            rubric = read(joinpath(generated, "RUBRIC.md"), String)
            @test occursin("Rubric", rubric)
            @test occursin("Public Criteria", rubric)
            @test occursin("Hidden Criteria", rubric)
            @test occursin("Public Code Properties", rubric)
        end
    end

    configured = joinpath(examples_root, "ConfiguredAssignment")
    config = SkeletonPackages.read_assignment_config(joinpath(configured, "SkeletonPackages.inc"))
    generated = generate_student_package(
        SkeletonPackages.AssignmentConfig(
            config.source_path,
            joinpath(tmp, "ConfiguredAssignmentStudentNotes"),
            config.mode,
            true,
            config.validate,
            config.instructions_path,
        );
        io=nothing,
    )
    instructions = read(joinpath(generated, "STUDENT_INSTRUCTIONS.md"), String)
    @test occursin("Configured Assignment Notes", instructions)
    @test occursin("Students should focus", instructions)
    @test !occursin("Teachers can keep private notes", instructions)
    rubric = read(joinpath(generated, "RUBRIC.md"), String)
    @test occursin("lowercases a simple name", rubric)
    @test occursin("handles tab and newline whitespace", rubric)
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

    if VERSION >= v"1.12"
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
    else
        @info "Skipping JET checks on Julia $VERSION; JET checks run on Julia 1.12 or later."
    end
end
