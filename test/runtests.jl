using SkeletonizePackage
using IncCSV
using Test

_same_path(a, b) = rstrip(abspath(a), ['/', '\\']) == rstrip(abspath(b), ['/', '\\'])
_deterministic_probe(x) = 2x

function _capture_main(args)
    out_path = tempname()
    err_path = tempname()
    try
        code = open(out_path, "w") do out
            open(err_path, "w") do err
                redirect_stdout(out) do
                    redirect_stderr(err) do
                        SkeletonizePackage.main(copy(args))
                    end
                end
            end
        end
        return code, read(out_path, String), read(err_path, String)
    finally
        rm(out_path; force=true)
        rm(err_path; force=true)
    end
end

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
$(forbidden_import ? "module DataFrames end\nusing .DataFrames" : "# no forbidden imports")
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

@testset "cli entry point" begin
    tmp = mktempdir()

    code, out, err = _capture_main(String[])
    @test code == 1
    @test isempty(out)
    @test occursin("Usage:", err)

    code, _, err = _capture_main(["unknown"])
    @test code == 1
    @test occursin("Usage:", err)

    assignment = create_assignment(joinpath(tmp, "CliReference"); ai_policy=:recorded)
    code, out, err = _capture_main(["validate", assignment])
    @test code == 0
    @test occursin("Validation report", out)
    @test isempty(err)

    bad = joinpath(tmp, "BadReference")
    mkpath(joinpath(bad, "src"))
    write(joinpath(bad, "Project.toml"), """
name = "BadReference"
uuid = "aaaaaaaa-0000-0000-0000-000000000010"
version = "0.1.0"
""")
    write(joinpath(bad, "src", "BadReference.jl"), """
module BadReference
using SkeletonizePackage
f() = @solution begin
    1
end
end
""")
    code, out, _ = _capture_main(["validate", bad])
    @test code == 2
    @test occursin("annotation appears inline", out)

    direct_skeleton = joinpath(tmp, "DirectSkeleton")
    code, out, err = _capture_main(["generate", assignment, direct_skeleton, "--force", "--no-validate", "--ai-policy", "allowed"])
    @test code == 0
    @test occursin(direct_skeleton, out)
    @test isfile(joinpath(direct_skeleton, "AGENTS.md"))
    @test occursin("AI Agent Use Is Allowed", read(joinpath(direct_skeleton, "AGENTS.md"), String))
    @test isempty(err)

    config_skeleton = joinpath(tmp, "ConfigSkeleton")
    config = SkeletonizePackage.read_assignment_config(joinpath(assignment, "SkeletonizePackage.inc"))
    config_path = joinpath(tmp, "CliConfig.inc")
    write(config_path, """
---
[assignment]
reference_path = "$(assignment)"
skeleton_path = "$(config_skeleton)"
mode = "$(String(config.mode))"
force = false
validate = true
instructions_path = "$(config.instructions_path)"
ai_policy = "recorded"
---
config
assignment
""")
    code, out, _ = _capture_main(["generate", "--config", config_path, "--force", "--ai-policy", "forbidden"])
    @test code == 0
    @test occursin(config_skeleton, out)
    @test occursin("AI Agents Are Forbidden", read(joinpath(config_skeleton, "AGENTS.md"), String))

    code, _, err = _capture_main(["generate", "--config"])
    @test code == 1
    @test occursin("--config requires a path", err)

    code, _, err = _capture_main(["generate", assignment])
    @test code == 1
    @test occursin("Usage:", err)

    init_path = joinpath(tmp, "CliInit")
    code, out, _ = _capture_main(["init", init_path, "--name", "CliInitCustom", "--force", "--ai-policy", "forbidden"])
    @test code == 0
    @test occursin(init_path, out)
    @test isfile(joinpath(init_path, "Project.toml"))
    init_config = SkeletonizePackage.read_assignment_config(joinpath(init_path, "SkeletonizePackage.inc"))
    @test init_config.ai_policy == :forbidden

    code, _, err = _capture_main(["create", joinpath(tmp, "BadPolicy"), "--ai-policy", "mystery"])
    @test code == 1
    @test occursin("ai_policy must be forbidden, recorded, or allowed", err)

    reference, passing_submission = _write_grade_fixture!(tmp; submission_name="CliPassing", passing=true)
    code, out, _ = _capture_main(["grade", reference, passing_submission, "--student-id", "cli-stdout"])
    @test code == 0
    @test occursin("Student Feedback Report", out)
    @test occursin("cli-stdout", out)

    report_path = joinpath(tmp, "cli-report.md")
    html_path = joinpath(tmp, "cli-report.html")
    gradescope_path = joinpath(tmp, "cli-gradescope.json")
    csv_path = joinpath(tmp, "cli-marks.csv")
    code, out, _ = _capture_main([
        "grade",
        reference,
        passing_submission,
        "--student-id",
        "cli-files",
        "--report",
        report_path,
        "--html",
        html_path,
        "--gradescope",
        gradescope_path,
        "--csv",
        csv_path,
        "--csv-format",
        "canvas",
        "--replace-csv",
        "--test-timeout",
        "60",
        "--ref-timeout",
        "20",
    ])
    @test code == 0
    @test occursin(report_path, out)
    @test occursin(html_path, out)
    @test occursin(gradescope_path, out)
    @test occursin(csv_path, out)
    @test startswith(read(csv_path, String), "SIS Login ID")
    @test occursin("cli-files", read(report_path, String))
    @test occursin("<html", read(html_path, String))
    @test occursin("\"score\"", read(gradescope_path, String))

    _, failing_submission = _write_grade_fixture!(tmp; submission_name="CliFailing", passing=false)
    code, out, _ = _capture_main(["grade", reference, failing_submission, "--student-id", "cli-fail"])
    @test code == 2
    @test occursin("Status: failed", out)

    code, _, err = _capture_main(["grade", reference, passing_submission, "--csv-format"])
    @test code == 1
    @test occursin("--csv-format requires a value", err)

    code, _, err = _capture_main(["init", joinpath(tmp, "NoName"), "--name"])
    @test code == 1
    @test occursin("--name requires a value", err)
end

@testset "property checkers" begin
    tmp = mktempdir()
    root = joinpath(tmp, "PropTest")
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "Project.toml"), """
name = "PropTest"
uuid = "aaaaaaaa-0000-0000-0000-000000000001"
version = "0.1.0"
""")
    write(joinpath(root, "src", "PropTest.jl"), """
module PropTest
using LinearAlgebra

export foo, bar

\"\"\"
    foo(x)

A documented function.
\"\"\"
function foo(x)
    global _g = x
    push!([], x)
    for i in 1:x
        for j in 1:i
            x + j
        end
    end
    return x
end

bar(x) = 2x

end
""")

    proj = SkeletonizePackage._source_project_from_path(root)

    @testset "_is_exported" begin
        @test  SkeletonizePackage._is_exported(proj, :foo)
        @test  SkeletonizePackage._is_exported(proj, :bar)
        @test !SkeletonizePackage._is_exported(proj, :baz)
    end

    @testset "_has_signature" begin
        @test  SkeletonizePackage._has_signature(proj, :foo, 1)
        @test !SkeletonizePackage._has_signature(proj, :foo, 2)
        @test !SkeletonizePackage._has_signature(proj, :missing_fn, 1)
    end

    @testset "_has_docstring" begin
        @test  SkeletonizePackage._has_docstring(proj, :foo)
        @test !SkeletonizePackage._has_docstring(proj, :bar)
    end

    @testset "_has_import" begin
        @test  SkeletonizePackage._has_import(proj, :LinearAlgebra)
        @test !SkeletonizePackage._has_import(proj, :DataFrames)
    end

    @testset "_calls" begin
        @test  SkeletonizePackage._calls(proj, :foo, :push!)
        @test !SkeletonizePackage._calls(proj, :foo, :sort!)
        @test !SkeletonizePackage._calls(proj, :bar, :push!)
        # project-wide search
        @test  SkeletonizePackage._calls(proj, nothing, :push!)
        @test !SkeletonizePackage._calls(proj, nothing, :nonexistent_fn)
    end

    @testset "_has_loop" begin
        @test  SkeletonizePackage._has_loop(proj, :foo)
        @test !SkeletonizePackage._has_loop(proj, :bar)
        @test !SkeletonizePackage._has_loop(proj, :missing_fn)
    end

    @testset "_has_global" begin
        @test  SkeletonizePackage._has_global(proj, :foo)
        @test !SkeletonizePackage._has_global(proj, :bar)
    end

    @testset "_has_side_effects" begin
        @test  SkeletonizePackage._has_side_effects(proj, :foo)
        @test !SkeletonizePackage._has_side_effects(proj, :bar)
    end

    @testset "_nested_loop_depth" begin
        @test SkeletonizePackage._nested_loop_depth(proj.text) == 2
        @test SkeletonizePackage._nested_loop_depth("x = 1\ny = 2\n") == 0
        @test SkeletonizePackage._nested_loop_depth("for i in 1:3\n  x = i\nend\n") == 1
        # loops inside conditionals do not double-count
        @test SkeletonizePackage._nested_loop_depth("if true\n  for i in 1:3\n    x = i\n  end\nend\n") == 1
    end

    @testset "_comment_count" begin
        @test SkeletonizePackage._comment_count(proj) == 0
        comment_proj = SkeletonizePackage.SourceProject(
            "",
            "Demo",
            Dict{String,String}(),
            """
            module Demo
            f() = 1 # inline comment
            g() = "# not a comment"
            #= block comment =#
            h() = \"\"\"# still not a comment\"\"\"
            end
            """,
            Dict{Symbol,SkeletonizePackage.SourceFunction}(),
        )
        @test SkeletonizePackage._comment_count(comment_proj) == 2
        empty_proj = SkeletonizePackage._source_project_from_path(let p = mktempdir()
            mkpath(joinpath(p, "src"))
            write(joinpath(p, "Project.toml"), "name = \"Empty\"\nuuid = \"aaaaaaaa-0000-0000-0000-000000000002\"\nversion = \"0.1.0\"\n")
            write(joinpath(p, "src", "Empty.jl"), "module Empty\nend\n")
            p
        end)
        @test SkeletonizePackage._comment_count(empty_proj) == 0
    end

    @testset "_lines_of_code" begin
        @test SkeletonizePackage._lines_of_code(proj) > 0
    end

    # Edge cases: function not found returns false, not an error
    @testset "missing function returns false" begin
        @test !SkeletonizePackage._has_loop(proj, :totally_missing)
        @test !SkeletonizePackage._has_global(proj, :totally_missing)
        @test !SkeletonizePackage._has_side_effects(proj, :totally_missing)
        @test !SkeletonizePackage._has_docstring(proj, :totally_missing)
        @test !SkeletonizePackage._has_signature(proj, :totally_missing, 1)
    end
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

    nested = """
function h(xs)
    @solution begin
        total = 0
        for x in xs
            if iseven(x)
                total += x
            end
        end
        return total
    end
    @scaffolding begin
        error("TODO nested")
    end
end
"""
    nested_student = strip_reference_annotations(nested; mode=:student)
    @test occursin("error(\"TODO nested\")", nested_student)
    @test !occursin("total += x", nested_student)

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
    @test !isfile(joinpath(dst, "student_notes.md"))
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
        "StringProcessingAssignment",
        "NumericalMethodsAssignment",
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

    # HTML report
    @test !isempty(passing.html_report)
    @test occursin("<html", passing.html_report)
    @test occursin("student-1", passing.html_report)
    html_file = joinpath(tmp, "feedback.html")
    grade_submission(reference, passing_submission; student_id="html-test", html_path=html_file)
    @test isfile(html_file)
    @test occursin("passed", read(html_file, String))

    # Gradescope JSON
    @test !isempty(passing.gradescope_json)
    @test occursin("\"score\"", passing.gradescope_json)
    @test occursin("student-1", passing.gradescope_json)
    gs_file = joinpath(tmp, "gradescope.json")
    grade_submission(reference, passing_submission; student_id="gs-test", gradescope_path=gs_file)
    @test isfile(gs_file)
    @test occursin("\"score\"", read(gs_file, String))

    # failure_category
    @test passing.failure_category == :none
    @test failing.failure_category == :test_failure
    @test forbidden.failure_category == :zero_gate

    # timed_out
    @test !passing.timed_out

    # LMS CSV formats
    h, r = passing.csv_header, passing.csv_row
    canvas_h, canvas_r = SkeletonizePackage._lms_csv(h, r, :canvas)
    @test startswith(canvas_h, "SIS Login ID")
    @test canvas_r == r
    moodle_h, _ = SkeletonizePackage._lms_csv(h, r, :moodle)
    @test startswith(moodle_h, "username")
    bb_h, _ = SkeletonizePackage._lms_csv(h, r, :blackboard)
    @test startswith(bb_h, "Username")
    @test_throws ArgumentError SkeletonizePackage._lms_csv(h, r, :unknown)
    lms_csv_file = joinpath(tmp, "canvas.csv")
    grade_submission(reference, passing_submission; student_id="canvas-1", csv_path=lms_csv_file, csv_format=:canvas)
    @test startswith(read(lms_csv_file, String), "SIS Login ID")

    # timeout parameter is accepted without error on normal submissions
    fast_result = grade_submission(reference, passing_submission; student_id="fast", test_timeout_seconds=60, reference_timeout_seconds=20)
    @test isvalid(fast_result)
    @test !fast_result.timed_out
end

@testset "_strip_code_noise" begin
    scn = SkeletonizePackage._strip_code_noise
    @test scn("x = 1 # comment")    == "x = 1          "
    @test scn("#= block =#\nx = 1") == "           \nx = 1"
    stripped_string = scn("x = \"hello\"")
    @test startswith(stripped_string, "x = ")
    @test length(stripped_string) == length("x = \"hello\"")
    @test !occursin("hello", stripped_string)
    stripped_triple = scn("x = \"\"\"hi\"\"\"")
    @test startswith(stripped_triple, "x = ")
    @test length(stripped_triple) == length("x = \"\"\"hi\"\"\"")
    @test !occursin("hi", stripped_triple)
    # preserves newlines inside stripped regions
    @test count(==('\n'), scn("#= a\nb =#\nx")) == count(==('\n'), "#= a\nb =#\nx")
    # nested block comments
    stripped_nested = scn("#= a #= b =# c =#")
    @test length(stripped_nested) == length("#= a #= b =# c =#")
    @test all(==(' '), stripped_nested)
    # keyword in comment is not counted
    @test !occursin("for",   scn("# for i in 1:10"))
    @test !occursin("push!", scn("x = \"push!(arr, v)\""))
end

@testset "_fmt_inline HTML formatting" begin
    fi = SkeletonizePackage._fmt_inline
    # Backtick code spans
    @test fi("`foo`")             == "<code>foo</code>"
    @test fi("see `bar` here")    == "see <code>bar</code> here"
    @test fi("a `b` c `d` e")     == "a <code>b</code> c <code>d</code> e"
    # Bold spans — the key regression test for the off-by-one bug
    @test fi("**bold**")          == "<strong>bold</strong>"
    @test fi("text **bold** end") == "text <strong>bold</strong> end"
    @test fi("**a** and **b**")   == "<strong>a</strong> and <strong>b</strong>"
    # HTML escaping in plain text
    @test occursin("&amp;",  fi("a & b"))
    @test occursin("&lt;",   fi("a < b"))
    # HTML escaping inside code spans
    @test fi("`a < b`")           == "<code>a &lt; b</code>"
    # No backticks — identity (modulo escaping)
    @test fi("plain text")        == "plain text"
    # Odd number of backticks → fallback to plain escaped text (no <code> wrapping)
    @test !occursin("<code>", fi("one `backtick"))
    @test  occursin("backtick",  fi("one `backtick"))
end

@testset "_json_string escaping" begin
    js = SkeletonizePackage._json_string
    @test js("hello")          == "\"hello\""
    @test js("say \"hi\"")     == "\"say \\\"hi\\\"\""
    @test js("line\nnewline")  == "\"line\\nnewline\""
    @test js("tab\there")      == "\"tab\\there\""
    # Control character below 0x20 (e.g. U+0001) must be escaped as 
    @test js("\x01")           == "\"\\u0001\""
    @test js("\x0b")           == "\"\\u000b\""   # vertical tab
    @test js("a\x00b")         == "\"a\\u0000b\""
    # Backslash
    @test js("a\\b")           == "\"a\\\\b\""
end

@testset "grade_submission early validation" begin
    tmp = mktempdir()
    reference, submission = _write_grade_fixture!(tmp; submission_name="EarlyVal", passing=true)
    @test_throws ArgumentError grade_submission(reference, submission; csv_format=:unknown)
    # Error thrown before any subprocess is started (ArgumentError, not a process error)
end

@testset "config mode validation" begin
    tmp = mktempdir()
    config_path = joinpath(tmp, "bad_mode.inc")
    write(config_path, """
---
[assignment]
reference_path = "."
skeleton_path = "../out"
mode = "sideways"
---
config
assignment
""")
    @test_throws ArgumentError SkeletonizePackage.read_assignment_config(config_path)
end

if get(ENV, "SKELETONIZE_RUN_QUALITY_TESTS", "true") == "true"
    include("aqua.jl")
    if VERSION.major == 1 && VERSION.minor == 12
        include("jet.jl")
    else
        @info "Skipping JET static analysis outside Julia 1.12.x" VERSION
    end
end
