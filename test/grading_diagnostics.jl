@testset "grading continues and separates outcomes from marks" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp)
        test_path = joinpath(reference, "test", "runtests.jl")
        write(test_path, """
using Reference, SkeletonizePackage, Test
const shared_value = 7
@student_test begin
    @marks 2 "same description" id="first"
    @test false
    @test shared_value == 7
end
@hidden_test begin
    @marks 3 "raises outside an assertion" id="error"
    error("broken setup inside a group")
    @test false
end
@hidden_test begin
    @marks 4 "later group" id="later"
    @testset "nested" begin
        @test answer() == 42
        @test_skip false
    end
end
include("included.jl")
@assignment_requirements begin
    @require exported(answer) marks=1 "exports answer"
end
""")
        write(joinpath(reference, "test", "included.jl"), """
@hidden_test begin
    @marks 5 "same description" id="included"
    @test isfile(joinpath(@__DIR__, "runtests.jl"))
end
""")
        out = IOBuffer()
        result = grade_submission(reference, submission; io=out)
        @test !isvalid(result)
        @test result.total_awarded == 1
        @test result.failure_category == :test_error
        diagnostic = String(take!(out))
        @test occursin("test_error", diagnostic)
        @test occursin("First diagnostic:", diagnostic)
        @test occursin("runtests.jl:", diagnostic)
        root = first(result.test_results)
        @test (root.passed, root.failed, root.errored, root.broken) == (3, 1, 1, 1)
        by_id = Dict(r.id => r for r in result.criterion_results)
        @test !by_id["first"].passed
        @test !by_id["error"].passed
        @test by_id["later"].passed
        @test by_id["included"].passed
        @test by_id["included"].awarded == 0
        @test occursin("marks withheld", by_id["included"].message)
        @test occursin("broken setup inside a group", result.stderr)
        @test occursin("Behavioral Test Results", result.student_report)
        @test occursin("Behavioral Test Results", result.html_report)

        strict = grade_submission(reference, submission; zero_on_failure=true, io=nothing,
            report_path=joinpath(tmp, "report.md"), html_path=joinpath(tmp, "report.html"),
            gradescope_path=joinpath(tmp, "gradescope.json"), csv_path=joinpath(tmp, "marks.csv"))
        @test strict.total_awarded == 0
        @test first(strict.test_results).passed == 3
        @test only(filter(r -> r.id == "included", strict.criterion_results)).passed
        @test endswith(strict.csv_row, ",0")
        @test occursin("\"score\": 0", strict.gradescope_json)
        @test read(joinpath(tmp, "report.md"), String) == strict.student_report
        @test read(joinpath(tmp, "report.html"), String) == strict.html_report
        @test read(joinpath(tmp, "gradescope.json"), String) == strict.gradescope_json
        @test occursin("test_error", strict.gradescope_json)
        @test occursin("passed: exports answer (must satisfy `exported(answer)`) (0 / 1 marks)", strict.student_report)
        @test !occursin("(1 / 1 marks)", strict.student_report)
        legacy = GradeResult((getfield(strict, i) for i in 1:21)...)
        @test legacy.total_awarded == strict.total_awarded
        @test isempty(legacy.test_results)
        plan = read(write_grading_plan(reference), String)
        checklist = read(write_teacher_checklist(reference), String)
        @test occursin("zero_on_failure=true", plan)
        @test occursin("dependency/loading", plan)
        @test occursin("unrun test groups", checklist)

        code, _, err = _capture_main(["grade", reference, submission, "--zero-on-failure", "--report", joinpath(tmp, "cli.md")])
        @test code == 2
        @test occursin("test_error", err)
        @test occursin("Total: 0 /", read(joinpath(tmp, "cli.md"), String))

        write(test_path, "using SkeletonizePackage, Test\nusing MissingGradingDependency12345\n@hidden_test begin\n    @marks 2 \"never reached\" id=\"unrun\"\n    @test true\nend\n")
        missing = grade_submission(reference, submission; io=nothing)
        @test missing.failure_category == :environment_failure
        @test occursin("MissingGradingDependency12345", missing.failure_message)
        @test occursin("instantiate", missing.failure_message)
        @test occursin("not run", only(filter(r -> r.id == "unrun", missing.criterion_results)).message)

        write(test_path, "using Test\n@testset \"before exit\" begin\n @test true\nend\nexit(0)\n@test false\n")
        exited = grade_submission(reference, submission; io=nothing)
        @test !isvalid(exited)
        @test exited.failure_category == :execution_failure
        @test first(exited.test_results).status == :incomplete
        @test first(exited.test_results).passed == 1

        write(test_path, "using Test\n@testset \"before timeout\" begin\n @test true\nend\nsleep(60)\n@test false\n")
        timeout = grade_submission(reference, submission; io=nothing, test_timeout_seconds=10)
        @test timeout.timed_out
        @test timeout.failure_category == :timeout
        @test first(timeout.test_results).passed == 1
        @test first(timeout.test_results).status == :incomplete

        write(test_path, "using Test\n@test true\n")
        passing = grade_submission(reference, submission; io=out)
        @test isvalid(passing)
        @test isempty(String(take!(out)))
        @test first(passing.test_results).passed == 1

        write(test_path, "using Test\n@hidden_test begin\n @marks 2 \"skipped group\" id=\"skipped\"\n @test_skip false\nend\n")
        skipped = grade_submission(reference, submission; io=nothing)
        @test !isvalid(skipped)
        @test skipped.total_awarded == 0
        @test first(skipped.test_results).status == :not_run
        @test first(skipped.test_results).broken == 1
        @test !only(filter(r -> r.id == "skipped", skipped.criterion_results)).passed
        @test_throws ArgumentError grade_submission(reference, submission; test_timeout_seconds=-1)
        @test_throws ArgumentError grade_submission(reference, submission; reference_timeout_seconds=-1)
    end
end

@testset "reference and property failures preserve behavioral outcomes" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp; forbidden_import=true)
        gated = grade_submission(reference, submission; io=nothing)
        @test gated.total_awarded == 0
        @test gated.failure_category == :zero_gate
        @test all(r -> r.passed, filter(r -> r.kind == :marks, gated.criterion_results))
        @test first(gated.test_results).passed == 2

        reference, submission = _write_grade_fixture!(tmp)
        write(joinpath(reference, "src", "Reference.jl"), "module Reference\nexport answer\nanswer() = error(\"reference implementation broken\")\nend\n")
        broken_reference = grade_submission(reference, submission; zero_on_failure=true, io=nothing)
        @test broken_reference.failure_category == :reference_failure
        @test broken_reference.total_awarded == 0
        @test first(broken_reference.test_results).passed == 2
        @test occursin("reference implementation broken", broken_reference.failure_message)
        @test all(r -> r.passed, filter(r -> r.kind == :marks, broken_reference.criterion_results))

        write(joinpath(reference, "test", "runtests.jl"), "using SkeletonizePackage, Test\n@test true\n@assignment_requirements begin\n @require exported(missing_name) marks=1 \"required interface\"\nend\n")
        property = grade_submission(reference, submission; io=nothing)
        @test property.failure_category == :property_failure
        @test first(property.test_results).passed == 1
    end
end

@testset "grading error diagnostics" begin
    categorize(err; code=1, zero=false) = first(SkeletonizePackage._categorize_failure(code, "", err, false, zero))
    @test categorize("Package X is required but does not seem to be installed") == :environment_failure
    @test categorize("Package X does not have Y in its dependencies") == :environment_failure
    @test categorize("Failed to precompile X") == :load_failure
    @test categorize("ParseError: invalid syntax") == :load_failure
    @test categorize("Could not launch grading subprocess: permission denied") == :execution_failure
    @test categorize("Test Failed"; zero=true) == :test_failure
    @test categorize(""; code=0, zero=true) == :zero_gate
    @test categorize("Package X not found"; code=0) == :none
    mktemp() do path, io
        write(io, "invalid = [")
        flush(io)
        results, message = SkeletonizePackage._read_behavioral_results(path)
        @test isempty(results)
        @test occursin("Could not read grading results", message)
    end
end
