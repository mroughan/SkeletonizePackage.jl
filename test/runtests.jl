using SkeletonizePackage
using IncCSV
using Test

_same_path(a, b) = rstrip(abspath(a), ['/', '\\']) == rstrip(abspath(b), ['/', '\\'])
_deterministic_probe(x) = 2x

function _write_grade_fixture!(root; submission_name="Submission", passing=true, forbidden_import=false)
    reference = joinpath(root, "Reference")
    submission = joinpath(root, submission_name)
    mkpath(joinpath(reference, "src"))
    mkpath(joinpath(reference, "test"))
    mkpath(joinpath(submission, "src"))
    mkpath(joinpath(submission, "test"))

    write(joinpath(reference, "Project.toml"), """
name = "Reference"
uuid = "7ab20f4c-9a1d-43a5-8e9d-54c7a5cb8eaa"
version = "0.1.0"

[deps]
SkeletonizePackage = "c8e6063d-6c4e-4aa4-bd9b-3a45f2ad7dd1"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
""")
    write(joinpath(reference, "src", "Reference.jl"), """
module Reference
using SkeletonizePackage
export answer
function answer()
    @solution begin
        42
    end
end
end
""")
    write(joinpath(reference, "test", "runtests.jl"), """
using Reference
using SkeletonizePackage
using Test

@student_test begin
    @marks 1 "answer returns an integer"
    @test answer() isa Integer
end

@hidden_test begin
    @marks 2 "answer returns forty-two"
    @test answer() == 42
    @reference_test answer generator=[()]
end

@assignment_requirements begin
    @require exported(answer) marks=1 "exports answer"
    @forbid imports(DataFrames) zero_marks=true "does not import DataFrames"
end
""")

    write(joinpath(submission, "Project.toml"), """
name = "$submission_name"
uuid = "943caa71-d73c-45f3-9d74-cad2c873d074"
version = "0.1.0"

[deps]
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
""")
    write(joinpath(submission, "src", "$submission_name.jl"), """
module $submission_name
export answer
# $(forbidden_import ? "using DataFrames" : "no forbidden imports")
answer() = $(passing ? 42 : 0)
end
""")
    write(joinpath(submission, "test", "runtests.jl"), """
using $submission_name
using Test

@test answer() == 42
""")
    return reference, submission
end

@testset "strip_reference_annotations" begin
    src = """
module Demo

function f(x)
    @solution begin
        return x + 1
    end
    @scaffolding begin
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

    student = strip_reference_annotations(src; mode=:student)
    @test occursin("error(\"TODO\")", student)
    @test !occursin("return x + 1", student)
    @test occursin("@test f(1) == 2", student)
    @test !occursin("@test f(100) == 101", student)
    @test occursin("@marks 1 \"public check for f\"", student)

    teacher = strip_reference_annotations(src; mode=:teacher)
    @test occursin("return x + 1", teacher)
    @test !occursin("error(\"TODO\")", teacher)
    @test occursin("@test f(100) == 101", teacher)
    @test occursin("@marks 2 \"hidden check for larger input\"", teacher)

    @test_throws ArgumentError strip_reference_annotations(src; mode=:invalid)
    @test_throws ArgumentError strip_reference_annotations("@solution begin\nx = 1"; mode=:student)
end

@testset "strip_reference_annotations preserves ordinary code" begin
    src = """
function g(xs)
    y = begin
        sum(xs)
    end
    @scaffolding begin
        return y
    end
end
"""

    student = strip_reference_annotations(src)
    @test occursin("y = begin", student)
    @test occursin("sum(xs)", student)
    @test occursin("return y", student)
end

@testset "macro runtime behaviour" begin
    @test (@solution begin 1 + 1 end) == 2
    @test (@scaffolding begin error("scaffolding should not run in reference package") end) === nothing
    @test (@student_test begin 3 + 4 end) == 7
    @test (@hidden_test begin 5 + 6 end) == 11
    @test (@marks 1 "runtime no-op") === nothing
end

@testset "assignment requirements macros" begin
    @assignment_requirements begin
        @require exported(generate_skeleton_package)
        @require exists(generate_skeleton_package)
        @require signature(read_assignment_config, 1)
        @require docstring(generate_skeleton_package)
        @require comments(min=0)
        @require lines_of_code(max=5000)
        @require nested_loop_depth(max=4)
        @require deterministic(_deterministic_probe)
        @forbid imports(DataFrames)
        @forbid calls(generate_skeleton_package, factorial)
        @reference_test generate_skeleton_package generator=1:3
    end
end

@testset "generate_skeleton_package" begin
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
using SkeletonizePackage
export f
f(x) = begin
    @solution begin
        x + 1
    end
    @scaffolding begin
        error("TODO")
    end
end
end
""")
    mkpath(joinpath(src, "test"))
    write(joinpath(src, "test", "runtests.jl"), """
using Demo
using SkeletonizePackage
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

@scaffolding begin
Student-facing hint.
end
""")
    generate_skeleton_package(src, dst; instructions_path=custom_notes, io=nothing)
    @test isfile(joinpath(dst, "src", "Demo.jl"))
    @test isfile(joinpath(dst, "STUDENT_INSTRUCTIONS.md"))
    @test isfile(joinpath(dst, "RUBRIC.md"))
    @test !isfile(joinpath(dst, "GRADING_PLAN.md"))
    @test !isfile(joinpath(dst, "TEACHER_CHECKLIST.md"))
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
    @test occursin("public-marks", rubric)

    plan_path = write_grading_plan(src)
    checklist_path = write_teacher_checklist(src)
    @test occursin("Teacher Grading Plan", read(plan_path, String))
    @test occursin("Teacher Checklist", read(checklist_path, String))

    teacher_dst = joinpath(tmp, "Teacher")
    generate_skeleton_package(src, teacher_dst; mode=:teacher, io=nothing)
    teacher_text = read(joinpath(teacher_dst, "src", "Demo.jl"), String)
    @test occursin("x + 1", teacher_text)
    @test !occursin("error(\"TODO\")", teacher_text)

    @test_throws ArgumentError generate_skeleton_package(src, teacher_dst; io=nothing)
    generate_skeleton_package(src, teacher_dst; force=true, io=nothing)
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
using SkeletonizePackage
f() = @solution begin
    1
end
@hidden begin
    2
end
end
""")

    report = validate_reference_package(src)
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
    @test isfile(joinpath(assignment, "GRADING_PLAN.md"))
    @test isfile(joinpath(assignment, "TEACHER_CHECKLIST.md"))
    config_path = joinpath(assignment, "SkeletonizePackage.inc")
    @test isfile(config_path)
    config_file = readinc(config_path)
    @test metadata(config_file)["assignment"]["reference_path"] == "."
    @test metadata(config_file)["assignment"]["validate"] == "true"
    @test metadata(config_file)["assignment"]["ai_policy"] == "recorded"

    report = validate_reference_package(assignment)
    @test isvalid(report)

    config = SkeletonizePackage.read_assignment_config(config_path)
    @test config.mode == :student
    @test config.instructions_path == joinpath(assignment, "student_notes.md")
    @test config.ai_policy == :recorded
    generated = generate_skeleton_package(config; io=nothing)
    @test isfile(joinpath(generated, "src", "DemoAssignment.jl"))
    @test isfile(joinpath(generated, "STUDENT_INSTRUCTIONS.md"))
    @test isfile(joinpath(generated, "AGENTS.md"))
    @test isfile(joinpath(generated, "RUBRIC.md"))
    @test !isfile(joinpath(generated, "GRADING_PLAN.md"))
    @test !isfile(joinpath(generated, "TEACHER_CHECKLIST.md"))
    text = read(joinpath(generated, "src", "DemoAssignment.jl"), String)
    @test occursin("TODO", text)
    @test !occursin("return 42", text)
    instructions = read(joinpath(generated, "STUDENT_INSTRUCTIONS.md"), String)
    @test occursin("Assignment Notes", instructions)
    agents = read(joinpath(generated, "AGENTS.md"), String)
    @test occursin("AI Agent Use Must Be Recorded", agents)
    @test occursin("record the tool name", agents)
    rubric = read(joinpath(generated, "RUBRIC.md"), String)
    @test occursin("answer returns an integer", rubric)
    @test occursin("answer returns the required value", rubric)
    @test occursin("exports the required function", rubric)
    @test occursin("public-answer-integer", rubric)

    forbidden_assignment = create_assignment(joinpath(tmp, "ForbiddenAssignment"); ai_policy=:forbidden)
    forbidden_config = SkeletonizePackage.read_assignment_config(joinpath(forbidden_assignment, "SkeletonizePackage.inc"))
    forbidden_generated = generate_skeleton_package(
        SkeletonizePackage.AssignmentConfig(
            forbidden_config.reference_path,
            joinpath(tmp, "ForbiddenAssignmentStudent"),
            forbidden_config.mode,
            true,
            forbidden_config.validate,
            forbidden_config.instructions_path,
            forbidden_config.ai_policy,
        );
        io=nothing,
    )
    @test occursin("AI Agents Are Forbidden", read(joinpath(forbidden_generated, "AGENTS.md"), String))

    allowed_generated = generate_skeleton_package(assignment, joinpath(tmp, "AllowedStudent"); force=true, ai_policy=:allowed, io=nothing)
    @test occursin("AI Agent Use Is Allowed", read(joinpath(allowed_generated, "AGENTS.md"), String))
    @test_throws ArgumentError generate_skeleton_package(assignment, joinpath(tmp, "BadPolicyStudent"); force=true, ai_policy=:unclear, io=nothing)
end

@testset "checked-in examples" begin
    examples_root = joinpath(@__DIR__, "..", "examples")
    examples = [
        "ThinAssignment",
        "SortingAssignment",
        "ConfiguredAssignment",
        "ReferenceOracleAssignment",
        "RecursiveAssignment",
        "ShortcutPolicyAssignment",
    ]

    tmp = mktempdir()
    for name in examples
        source = joinpath(examples_root, name)
        @testset "$name" begin
            report = validate_reference_package(source)
            @test isvalid(report)

            config_path = joinpath(source, "SkeletonizePackage.inc")
            if isfile(config_path)
                config = SkeletonizePackage.read_assignment_config(config_path)
                @test _same_path(config.reference_path, source)
                test_config = SkeletonizePackage.AssignmentConfig(
                    config.reference_path,
                    joinpath(tmp, "$(name)Student"),
                    config.mode,
                    true,
                    config.validate,
                    config.instructions_path,
                    config.ai_policy,
                )
                generated = generate_skeleton_package(test_config; io=nothing)
            else
                generated = generate_skeleton_package(source, joinpath(tmp, "$(name)Student"); io=nothing)
            end

            @test isfile(joinpath(generated, "Project.toml"))
            @test isfile(joinpath(generated, "AGENTS.md"))
            @test !isfile(joinpath(generated, "GRADING_PLAN.md"))
            @test !isfile(joinpath(generated, "TEACHER_CHECKLIST.md"))
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
    config = SkeletonizePackage.read_assignment_config(joinpath(configured, "SkeletonizePackage.inc"))
    generated = generate_skeleton_package(
        SkeletonizePackage.AssignmentConfig(
            config.reference_path,
            joinpath(tmp, "ConfiguredAssignmentStudentNotes"),
            config.mode,
            true,
            config.validate,
            config.instructions_path,
            config.ai_policy,
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

@testset "golden generated snippets" begin
    tmp = mktempdir()
    source = joinpath(@__DIR__, "..", "examples", "SortingAssignment")
    generated = generate_skeleton_package(source, joinpath(tmp, "SortingAssignmentStudent"); force=true, io=nothing)

    source_text = read(joinpath(generated, "src", "SortingAssignment.jl"), String)
    @test occursin("error(\"TODO: implement mysort\")", source_text)
    @test !occursin("return sort", source_text)

    rubric = read(joinpath(generated, "RUBRIC.md"), String)
    @test occursin("# Rubric", rubric)
    @test occursin("Total: 9 marks", rubric)
    @test occursin("sorts a simple two-element vector", rubric)
    @test occursin("does not use a package that solves sorting", rubric)

    agents = read(joinpath(generated, "AGENTS.md"), String)
    @test occursin("AI Agent Use Must Be Recorded", agents)
    @test occursin("Students must not use AI to bypass the purpose of the assignment", agents)

    instructions = read(joinpath(generated, "STUDENT_INSTRUCTIONS.md"), String)
    @test occursin("Getting Started", instructions)
    @test occursin("Pkg.instantiate()", instructions)
end

@testset "grade result" begin
    result = SkeletonizePackage.GradeResult(true, 0, "ok", "")
    @test isvalid(result)
    @test occursin("passed", sprint(show, result))
    @test occursin("Student Feedback Report", result.student_report)
    @test result.csv_header == "student_id,status,total"

    tmp = mktempdir()
    reference, passing_submission = _write_grade_fixture!(tmp; submission_name="PassingSubmission", passing=true)
    report_path = joinpath(tmp, "feedback.md")
    csv_path = joinpath(tmp, "marks.csv")
    passing = grade_submission(
        reference,
        passing_submission;
        student_id="student-1",
        report_path=report_path,
        csv_path=csv_path,
    )
    @test isvalid(passing)
    @test passing.total_awarded == 4
    @test passing.total_possible == 4
    @test passing.awarded_by_category["public"] == 2
    @test passing.awarded_by_category["hidden"] == 2
    @test passing.csv_header == "student_id,status,hidden,public,total"
    @test passing.csv_row == "student-1,passed,2,2,4"
    @test occursin("answer returns forty-two: 2 / 2 marks", passing.student_report)
    @test occursin("passed: exports answer", passing.student_report)
    @test occursin("does not import DataFrames", passing.student_report)
    @test length(passing.reference_test_results) == 1
    @test only(passing.reference_test_results).passed
    @test !isempty(passing.criterion_results)
    @test any(result -> result.kind == :require && occursin("exports-answer", result.id), passing.criterion_results)
    @test any(result -> result.awarded == 1 && result.kind == :require, passing.criterion_results)
    @test occursin("Reference Tests", passing.student_report)
    @test occursin("matched reference output", passing.student_report)
    @test read(report_path, String) == passing.student_report
    @test split(chomp(read(csv_path, String)), '\n') == [passing.csv_header, passing.csv_row]

    _, failing_submission = _write_grade_fixture!(tmp; submission_name="FailingSubmission", passing=false)
    failing = grade_submission(
        reference,
        failing_submission;
        student_id="student,2",
        csv_path=csv_path,
    )
    @test !isvalid(failing)
    @test failing.total_awarded == 1
    @test failing.total_possible == 4
    @test failing.csv_row == "\"student,2\",failed,0,1,1"
    @test occursin("Status: failed", failing.student_report)
    @test length(failing.reference_test_results) == 1
    @test !only(failing.reference_test_results).passed
    @test occursin("expected 42, got 0", failing.student_report)
    @test length(split(chomp(read(csv_path, String)), '\n')) == 3

    _, forbidden_submission = _write_grade_fixture!(tmp; submission_name="ForbiddenSubmission", passing=true, forbidden_import=true)
    forbidden = grade_submission(reference, forbidden_submission; student_id="student-3")
    @test !isvalid(forbidden)
    @test forbidden.total_awarded == 0
    @test forbidden.total_possible == 4
    @test occursin("Zeroes assignment if failed", forbidden.student_report)

    cli_report = joinpath(tmp, "cli-feedback.md")
    cli_csv = joinpath(tmp, "cli-marks.csv")
    @test SkeletonizePackage.main([
        "grade",
        reference,
        passing_submission,
        "--student-id",
        "cli-student",
        "--report",
        cli_report,
        "--csv",
        cli_csv,
    ]) == 0
    @test occursin("cli-student,passed,2,2,4", read(cli_csv, String))
    @test occursin("Student: `cli-student`", read(cli_report, String))
end
