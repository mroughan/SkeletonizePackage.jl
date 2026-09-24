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
        @test isempty(result.test_results)
    end

    @testset "documented grading examples" begin
        mktempdir() do tmp
            for (name, expected_row, expected_count) in [
                ("SortingAssignment", "s123,passed,4,5,9", 7),
                ("ReferenceOracleAssignment", "s123,passed,3,3,6", 3),
            ]
                reference = joinpath(@__DIR__, "..", "examples", name)
                submission = generate_skeleton_package(reference, joinpath(tmp, name);
                    mode=:teacher, validate=false, io=nothing)
                # A completed submission no longer needs the stripped annotation macros.
                source_path = joinpath(submission, "src", "$name.jl")
                write(source_path, replace(read(source_path, String), "using SkeletonizePackage" => ""))
                project_path = joinpath(submission, "Project.toml")
                project = SkeletonizePackage.TOML.parsefile(project_path)
                delete!(project["deps"], "SkeletonizePackage")
                open(project_path, "w") do io
                    SkeletonizePackage.TOML.print(io, project)
                end
                result = grade_submission(reference, submission; student_id="s123", io=nothing)
                @test isvalid(result)
                @test result.csv_header == "student_id,status,hidden,public,total"
                @test result.csv_row == expected_row
                @test startswith(result.student_report, "# Student Feedback Report")
                @test !isempty(result.html_report)
                @test !isempty(result.gradescope_json)
                @test first(result.test_results).passed == expected_count
                @test all(r -> r.passed, result.criterion_results)
                @test all(r -> r.passed, result.reference_test_results)
                if name == "ReferenceOracleAssignment"
                    @test length(result.reference_test_results) == 6
                    tests = read(joinpath(reference, "test", "runtests.jl"), String)
                    example = match(r"@hidden_test begin.*?\nend"s, tests).match
                    for page in ("index.md", "requirements.md")
                        @test occursin(example, read(joinpath(@__DIR__, "..", "docs", "src", page), String))
                    end
                end
            end
        end
    end

    @testset "generated grading guidance" begin
        mktempdir() do tmp
            reference = create_assignment(joinpath(tmp, "GuidanceAssignment"))
            skeleton = generate_skeleton_package(reference, joinpath(tmp, "Skeleton");
                validate=false, io=nothing)
            readme = read(joinpath(reference, "README.md"), String)
            plan = read(joinpath(reference, "GRADING_PLAN.md"), String)
            checklist = read(joinpath(reference, "TEACHER_CHECKLIST.md"), String)
            instructions = read(joinpath(skeleton, "STUDENT_INSTRUCTIONS.md"), String)
            rubric = read(joinpath(skeleton, "RUBRIC.md"), String)
            @test occursin("zero_on_failure=true", readme)
            @test occursin("does not install dependencies", readme)
            @test occursin("before sharing them", plan)
            @test occursin("not an INC generation setting", plan)
            @test occursin("Preserve original submissions", checklist)
            @test occursin("hidden-test details", checklist)
            @test occursin("outcomes separately from awarded marks", instructions)
            @test occursin("Local `Pkg.test()`", instructions)
            @test occursin("does not imply partial credit", rubric)
            @test occursin("without hiding passing", rubric)
            @test occursin("reports outcomes separately", read(joinpath(skeleton, "README.md"), String))
        end
    end

    @testset "architecture configuration example" begin
        architecture = read(joinpath(@__DIR__, "..", "ARCHITECTURE.md"), String)
        example = match(r"```text\n(---\n\[assignment\].*?)\n```"s, architecture).captures[1]
        mktempdir() do tmp
            config_path = joinpath(tmp, "SkeletonizePackage.inc")
            write(config_path, example)
            config = read_assignment_config(config_path)
            @test config.reference_path == tmp
            @test basename(config.skeleton_path) == "SortingAssignmentStudent"
            @test config.mode == :student
            @test config.ai_policy == :recorded
        end
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
