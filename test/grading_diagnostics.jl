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
        @test !occursin("ASSIGNMENT ZEROED", diagnostic)
        @test !occursin("ASSIGNMENT ZEROED", result.student_report)
        @test startswith(result.failure_message, "BEHAVIORAL MARKS WITHHELD:")
        @test occursin("BEHAVIORAL MARKS WITHHELD", first(split(diagnostic, '\n')))
        @test occursin("Property checks are scored separately", result.failure_message)
        @test occursin("no fatal zero-mark rule was triggered", result.failure_message)
        top = first(split(result.student_report, "## Behavioral Test Results"))
        @test occursin("## BEHAVIORAL MARKS WITHHELD", top)
        @test occursin("withholds all 14 behavioral marks", top)
        @test occursin("$(test_path):5", top)
        @test occursin("does not itself indicate forbidden code", top)
        @test occursin("BEHAVIORAL MARKS WITHHELD", result.html_report)
        @test occursin("BEHAVIORAL MARKS WITHHELD", result.gradescope_json)
        root = first(result.test_results)
        @test (root.passed, root.failed, root.errored, root.broken) == (3, 1, 1, 1)
        by_id = Dict(r.id => r for r in result.criterion_results)
        @test !by_id["first"].passed
        @test !by_id["error"].passed
        @test by_id["later"].passed
        @test by_id["included"].passed
        @test by_id["included"].awarded == 0
        @test occursin("marks withheld", by_id["included"].message)
        @test occursin("see BEHAVIORAL MARKS WITHHELD", by_id["included"].message)
        @test occursin("broken setup inside a group", result.stderr)
        @test occursin("Behavioral Test Results", result.student_report)
        @test occursin("Behavioral Test Results", result.html_report)
        feedback = first(split(result.student_report, "## Test Output"))
        @test occursin("Checks: 3 of 4 evaluated checks met expectations", feedback)
        @test occursin("same description: 1 of 2 evaluated checks met expectations", feedback)
        @test occursin("1 evaluation error;", feedback)
        @test !occursin("..", feedback)
        @test !occursin("Status:", feedback)
        @test !occursin("Failure:", feedback)
        @test !occursin(": **failed**", feedback)
        @test !occursin("failed:", feedback)
        @test !occursin("<strong>TEST_ERROR</strong>", result.html_report)
        @test occursin("Test Failed at", result.student_report)
        @test occursin("Diagnostic category: `test_error`", result.student_report)

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
        @test occursin("satisfied: exports answer (must satisfy `exported(answer)`) (0 / 1 marks)", strict.student_report)
        @test !occursin("(1 / 1 marks)", strict.student_report)
        @test occursin("## ASSIGNMENT ZEROED", first(split(strict.student_report, "## Behavioral Test Results")))
        @test occursin("Total: 0 / 15 marks", strict.student_report)
        @test occursin("Checks: 3 of 4 evaluated checks met expectations", strict.student_report)
        @test !occursin("BEHAVIORAL MARKS WITHHELD", strict.student_report)
        @test occursin("All marks are withheld", strict.student_report)
        @test occursin("zero_on_failure=true", strict.failure_message)
        @test occursin("Test group \"same description\"", strict.failure_message)
        @test occursin("$(test_path):5", strict.failure_message)
        @test occursin("<h2>ASSIGNMENT ZEROED</h2>", strict.html_report)
        @test occursin("ASSIGNMENT ZEROED", strict.gradescope_json)
        legacy = GradeResult((getfield(strict, i) for i in 1:21)...)
        @test legacy.total_awarded == strict.total_awarded
        @test isempty(legacy.test_results)
        plan = read(write_grading_plan(reference), String)
        checklist = read(write_teacher_checklist(reference), String)
        @test occursin("zero_on_failure=true", plan)
        @test occursin("dependency/loading", plan)
        @test occursin("ASSIGNMENT ZEROED", plan)
        @test occursin("BEHAVIORAL MARKS WITHHELD", plan)
        @test occursin("ASSIGNMENT ZEROED", checklist)
        @test occursin("unrun test groups", checklist)

        code, _, err = _capture_main(["grade", reference, submission, "--zero-on-failure", "--report", joinpath(tmp, "cli.md")])
        @test code == 2
        @test occursin("test_error", err)
        @test occursin("ASSIGNMENT ZEROED", first(split(err, '\n')))
        @test occursin("$(test_path):5", first(split(err, '\n')))
        @test occursin("Total: 0 /", read(joinpath(tmp, "cli.md"), String))

        write(test_path, "using SkeletonizePackage, Test\nusing MissingGradingDependency12345\n@hidden_test begin\n    @marks 2 \"never reached\" id=\"unrun\"\n    @test true\nend\n")
        missing = grade_submission(reference, submission; zero_on_failure=true, io=nothing)
        @test missing.failure_category == :environment_failure
        @test occursin("MissingGradingDependency12345", missing.failure_message)
        @test occursin("instantiate", missing.failure_message)
        @test occursin("not run", only(filter(r -> r.id == "unrun", missing.criterion_results)).message)
        @test occursin("ASSIGNMENT ZEROED", missing.failure_message)
        @test occursin("zero_on_failure=true", missing.failure_message)
        @test occursin("needs review before the mark is finalized", missing.student_report)

        write(test_path, "using Test\n@testset \"before exit\" begin\n @test true\nend\nexit(0)\n@test false\n")
        exited = grade_submission(reference, submission; io=nothing)
        @test !isvalid(exited)
        @test exited.failure_category == :execution_failure
        @test first(exited.test_results).status == :incomplete
        @test first(exited.test_results).passed == 1
        @test occursin("Execution was interrupted", exited.student_report)

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
        @test occursin("Checks: 1 of 1 evaluated checks met expectations", passing.student_report)
        @test !occursin("Status:", passing.student_report)
        @test !occursin("BEHAVIORAL MARKS WITHHELD", passing.student_report)

        write(test_path, "using Test\n@hidden_test begin\n @marks 2 \"skipped group\" id=\"skipped\"\n @test_skip false\nend\n")
        skipped = grade_submission(reference, submission; io=nothing)
        @test !isvalid(skipped)
        @test skipped.total_awarded == 0
        @test first(skipped.test_results).status == :not_run
        @test first(skipped.test_results).broken == 1
        @test occursin("No checks were evaluated", skipped.student_report)
        @test !only(filter(r -> r.id == "skipped", skipped.criterion_results)).passed
        @test_throws ArgumentError grade_submission(reference, submission; test_timeout_seconds=-1)
        @test_throws ArgumentError grade_submission(reference, submission; reference_timeout_seconds=-1)
    end
end

@testset "reference and property failures preserve behavioral outcomes" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp; forbidden_import=true)
        diagnostics = IOBuffer()
        gated = grade_submission(reference, submission; io=diagnostics)
        @test gated.total_awarded == 0
        @test gated.failure_category == :zero_gate
        @test all(r -> r.passed, filter(r -> r.kind == :marks, gated.criterion_results))
        @test first(gated.test_results).passed == 2
        test_path = joinpath(reference, "test", "runtests.jl")
        line = findfirst(s -> occursin("@forbid imports", s), readlines(test_path))
        location = "$test_path:$line"
        @test occursin("zero_marks=true", gated.failure_message)
        @test occursin("does not import DataFrames", gated.failure_message)
        @test occursin("Rule declared at $location", gated.failure_message)
        @test occursin("ASSIGNMENT ZEROED", String(take!(diagnostics)))
        @test occursin("## ASSIGNMENT ZEROED", first(split(gated.student_report, "## Behavioral Test Results")))
        @test occursin("Checks: 2 of 2 evaluated checks met expectations", gated.student_report)
        @test occursin(location, first(split(gated.student_report, "## Behavioral Test Results")))
        @test occursin("ASSIGNMENT ZEROED", gated.html_report)
        @test occursin("ASSIGNMENT ZEROED", gated.gradescope_json)
        @test !occursin("BEHAVIORAL MARKS WITHHELD", gated.student_report)

        reference, submission = _write_grade_fixture!(tmp)
        write(joinpath(reference, "src", "Reference.jl"), "module Reference\nexport answer\nanswer() = error(\"reference implementation broken\")\nend\n")
        broken_reference = grade_submission(reference, submission; zero_on_failure=true, io=nothing)
        @test broken_reference.failure_category == :reference_failure
        @test broken_reference.total_awarded == 0
        @test first(broken_reference.test_results).passed == 2
        @test occursin("reference implementation broken", broken_reference.failure_message)
        @test all(r -> r.passed, filter(r -> r.kind == :marks, broken_reference.criterion_results))
        @test occursin("zero_on_failure=true", broken_reference.failure_message)
        @test occursin("Reference test answer, input 1", broken_reference.failure_message)
        @test occursin("Oracle declaration(s):", broken_reference.failure_message)
        default_reference = grade_submission(reference, submission; io=nothing)
        @test default_reference.total_awarded == 1
        @test default_reference.failure_category == :reference_failure
        @test startswith(default_reference.failure_message, "BEHAVIORAL MARKS WITHHELD:")
        @test occursin("Reference test answer, input 1", default_reference.failure_message)
        @test occursin("$(test_path):13", default_reference.failure_message)

        write(joinpath(reference, "test", "runtests.jl"), "using SkeletonizePackage, Test\n@test true\n@assignment_requirements begin\n @require exported(missing_name) marks=1 \"required interface\"\nend\n")
        property = grade_submission(reference, submission; io=nothing)
        @test property.failure_category == :property_failure
        @test first(property.test_results).passed == 1
    end
end

@testset "zero total without a fatal rule" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp; passing=false)
        test_path = joinpath(reference, "test", "runtests.jl")
        write(test_path, first(split(read(test_path, String), "@assignment_requirements")))
        result = grade_submission(reference, submission; io=nothing)
        @test result.total_awarded == 0
        @test result.total_possible == 3
        @test startswith(result.failure_message, "BEHAVIORAL MARKS WITHHELD:")
        @test occursin("withholds all 3 behavioral marks", result.student_report)
        @test !occursin("ASSIGNMENT ZEROED", result.student_report)
        @test isempty(result.property_results)
    end
end

@testset "moderate student report wording" begin
    summary = SkeletonizePackage._student_test_summary
    checks = (status=:failed, passed=62, failed=1, errored=0, broken=0)
    @test summary(checks) == "62 of 63 evaluated checks met expectations; 1 did not meet expectations; 0 evaluation errors; 0 skipped/expected-broken."
    @test occursin("Checks: " * summary(checks), read(joinpath(@__DIR__, "..", "docs", "src", "grading.md"), String))
    @test !occursin("failed", summary(checks))
    @test SkeletonizePackage._brief_failure_detail("Test Failed at checks.jl:9\nExpression: answer() == 42") ==
        "Check did not meet expectations at checks.jl:9 Expression: answer() == 42"
    @test occursin("Execution was interrupted", summary(merge(checks, (status=:incomplete,))))
    @test occursin("An exception", summary(merge(checks, (status=:error, errored=1))))
    @test occursin("No checks were evaluated", summary((status=:not_run, passed=0, failed=0, errored=0, broken=1)))
    html = SkeletonizePackage._build_html_report("# Student Feedback Report\nTotal: 1 / 2 marks\n", :test_failure, "Examiner-only diagnostic")
    @test !occursin("TEST_FAILURE", html)
    @test !occursin("Examiner-only diagnostic", html)
    @test occursin("Total: 1 / 2 marks", html)
end

@testset "multiple zeroing causes and included assertion locations" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp; passing=false, forbidden_import=true)
        test_path = joinpath(reference, "test", "runtests.jl")
        open(test_path, "a") do io
            write(io, "\n@assignment_requirements begin\n    @require exists(missing_function) zero_marks=true id=\"fatal-interface\" \"required function\"\nend\ninclude(\"extra.jl\")\n")
        end
        included_path = joinpath(reference, "test", "extra.jl")
        write(included_path, "@testset \"extra <check>\" begin\n    @test false\n    @test true\nend\n")
        out = IOBuffer()
        result = grade_submission(reference, submission; zero_on_failure=true, io=out)
        @test result.total_awarded == 0
        @test result.failure_category == :test_failure
        @test first(result.test_results).passed == 2
        @test first(result.test_results).failed == 2
        top = first(split(result.student_report, "## Behavioral Test Results"))
        @test occursin("does not import DataFrames", top)
        @test occursin("[fatal-interface]", top)
        @test occursin("$included_path:2", top)
        @test occursin("Test group \"extra <check>\"", top)
        @test occursin("extra &lt;check&gt;", result.html_report)
        @test !occursin("extra <check>", result.html_report)
        summary = first(split(String(take!(out)), '\n'))
        @test occursin("ASSIGNMENT ZEROED", summary)
        @test occursin("[fatal-interface]", summary)
        @test occursin("more zeroing causes; see report", summary)
    end
end

@testset "zero-policy notices without assertion evidence" begin
    reasons = SkeletonizePackage._zero_mark_reasons(
        SkeletonizePackage.RubricItem[], CriterionResult[], NamedTuple[], ReferenceTestResult[],
        SkeletonizePackage.ReferenceTestSpec[]; reference_path="/reference", zero_on_failure=true,
        behavioral_passed=false, failure_message="Process interrupted.")
    @test occursin("zero_on_failure=true", only(reasons))
    @test occursin("No failed assertion location was recorded", only(reasons))
    @test !occursin("Test Failed", only(reasons))
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
