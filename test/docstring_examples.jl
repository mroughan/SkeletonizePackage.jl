@testset "docstring examples" begin
    @testset "annotation macro examples" begin
        @test (@solution begin
            2 + 3
        end) == 5

        @test (@scaffolding begin
            error("TODO")
        end) === nothing

        @test (@student_test begin
            3 + 4
        end) == 7

        @test (@hidden_test begin
            5 + 6
        end) == 11

        @test (@marks 1 "sorts a two-element vector" id="sort-basic") === nothing
        @test (@assignment_requirements begin
            @require exported(mysort) marks=1 id="interface-export" "exports the required function"
            @require signature(mysort, 1)
            @forbid calls(mysort, sort)
            @forbid imports(DataFrames) zero_marks=true "does not use a shortcut package"
            @reference_test fib generator=1:10
        end) === nothing
    end

    @testset "AssignmentConfig example" begin
        config = AssignmentConfig("Reference", "Skeleton", :student, true, true, nothing, :recorded)
        @test config.reference_path == "Reference"
        @test config.skeleton_path == "Skeleton"
    end

    @testset "read_assignment_config example" begin
        tmp = mktempdir()
        root = joinpath(tmp, "MyAssignment")
        mkpath(root)
        config_path = joinpath(root, "SkeletonizePackage.inc")
        write(config_path, """
---
[assignment]
reference_path = "."
skeleton_path = "../MyAssignmentSkeleton"
mode = "student"
force = true
validate = true
ai_policy = "forbidden"
---
config
assignment
""")

        config = read_assignment_config(config_path)
        @test basename(config.reference_path) == "MyAssignment"
        @test basename(config.skeleton_path) == "MyAssignmentSkeleton"
        @test config.force
    end

    @testset "generate_skeleton_package examples" begin
        tmp = mktempdir()
        examples_root = joinpath(@__DIR__, "..", "examples")

        skeleton = generate_skeleton_package(
            joinpath(examples_root, "SortingAssignment"),
            joinpath(tmp, "SortingAssignmentSkeleton");
            force=true,
            io=nothing,
        )
        @test basename(skeleton) == "SortingAssignmentSkeleton"
        @test isfile(joinpath(skeleton, "RUBRIC.md"))
        @test isfile(joinpath(skeleton, "STUDENT_INSTRUCTIONS.md"))

        configured_reference = joinpath(tmp, "ConfiguredAssignment")
        cp(joinpath(examples_root, "ConfiguredAssignment"), configured_reference)
        configured = generate_skeleton_package(joinpath(configured_reference, "SkeletonizePackage.inc"); io=nothing)
        @test endswith(configured, "ConfiguredAssignmentStudent")
    end

    @testset "GradeResult example" begin
        result = GradeResult(true, 0, "ok", "")
        @test isvalid(result)
        @test result.csv_header == "student_id,status,total"
        @test result.csv_row == ",passed,0"
    end

    @testset "ValidationIssue and ValidationReport examples" begin
        issue = ValidationIssue(:warning, "test/runtests.jl", 3, "no @student_test blocks found", "Add visible tests.")
        @test sprint(show, issue) == "WARNING test/runtests.jl:3: no @student_test blocks found\n  suggestion: Add visible tests."

        report = ValidationReport("Reference", ValidationIssue[])
        @test isvalid(report)
        @test sprint(show, report) == "Validation report for Reference\n0 errors, 0 warnings, 0 notes\nNo issues found."
    end

    @testset "validate_reference_package example" begin
        report = validate_reference_package(joinpath(@__DIR__, "..", "examples", "SortingAssignment"))
        @test isvalid(report)
        @test startswith(sprint(show, report), "Validation report")
    end

    @testset "strip_reference_annotations example" begin
        text = """
        function f()
            @solution begin
                return 42
            end
            @scaffolding begin
                error("TODO")
            end
        end
        """

        @test strip_reference_annotations(text; mode=:student) == """
        function f()
                error("TODO")
        end
        """
        @test strip_reference_annotations(text; mode=:teacher) == """
        function f()
                return 42
        end
        """
    end
end
