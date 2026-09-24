@testset "proportional group credit and explicit all-or-nothing" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp)
        test_path = joinpath(reference, "test", "runtests.jl")
        write(test_path, """
using Reference, SkeletonizePackage, Test
@student_test begin
    @marks 3 "mixed checks" id="partial"
    @test true
    @test false
end
@hidden_test begin
    @marks 3 "atomic checks" id="atomic" all_or_nothing=true
    @test true
    @test false
end
@hidden_test begin
    @marks 2 "nested checks" id="nested" all_or_nothing=false
    @testset "inner" begin
        @test true
        @test_skip false
        @test_broken false
    end
end
@hidden_test begin
    @marks 4 "assertion error" id="assertion-error"
    @test true
    @test error("inside assertion")
end
@hidden_test begin
    @marks 4 "aborted setup" id="aborted"
    @test true
    error("outside assertion")
    @test true
end
@hidden_test begin
    @marks 2 "first shared criterion" id="shared-first"
    @test true
    @marks 3 "second shared criterion" id="shared-second" all_or_nothing=true
    @test false
end
@hidden_test begin
    @marks 2 "all-or-nothing met" id="atomic-met" all_or_nothing=true
    @test true
end
@hidden_test begin
    @marks 2 "only skipped" id="skipped"
    @test_skip false
end
@hidden_test begin
    @marks 2 "empty" id="empty"
end
@hidden_test begin
    @marks 1 "thirds" id="thirds"
    @test true
    @test false
    @test false
end
@assignment_requirements begin
    @require exported(answer) marks=1 "exports answer"
end
""")
        csv = joinpath(tmp, "marks.csv")
        diagnostic = IOBuffer()
        result = grade_submission(reference, submission; io=diagnostic, csv_path=csv, csv_format=:canvas)
        by_id = Dict(c.id => c for c in result.criterion_results)
        @test by_id["partial"].awarded == 1.5
        @test !by_id["partial"].passed
        @test by_id["atomic"].awarded == 0
        @test occursin("all_or_nothing=true", by_id["atomic"].message)
        @test occursin("$test_path:8", by_id["atomic"].message)
        @test occursin("$test_path:10", by_id["atomic"].message)
        @test occursin("GROUP MARKS ZEROED", String(take!(diagnostic)))
        @test occursin("GROUP MARKS ZEROED", result.failure_message)
        @test occursin("GROUP MARKS ZEROED", result.html_report)
        @test occursin("GROUP MARKS ZEROED", result.gradescope_json)
        @test findfirst("GROUP MARKS ZEROED", result.student_report).start < findfirst("Behavioral Test Results", result.student_report).start
        @test !occursin("ASSIGNMENT ZEROED", result.student_report)
        @test by_id["nested"].awarded == 2
        @test by_id["assertion-error"].awarded == 2
        @test by_id["aborted"].awarded == 0
        @test occursin("remaining check count is unknown", by_id["aborted"].message)
        @test by_id["shared-first"].awarded == 0
        @test by_id["shared-second"].awarded == 0
        @test by_id["atomic-met"].awarded == 2
        @test by_id["atomic-met"].passed
        @test by_id["skipped"].awarded == 0
        @test by_id["empty"].awarded == 0
        @test by_id["thirds"].awarded ≈ 1 / 3
        @test result.total_awarded ≈ 8.5 + 1 / 3
        @test result.total_awarded ≈ sum(c.awarded for c in result.criterion_results)
        @test result.total_awarded ≈ sum(values(result.awarded_by_category))
        @test occursin("mixed checks: 1.5 / 3 marks", result.student_report)
        @test occursin("mixed checks: 1.5 / 3 marks", result.html_report)
        @test occursin("\"score\": 1.5", result.gradescope_json)
        @test startswith(read(csv, String), "SIS Login ID")
        @test parse(Float64, last(split(result.csv_row, ','))) ≈ result.total_awarded
        @test !occursin("BEHAVIORAL MARKS WITHHELD", result.student_report)
        atomic_item = only(filter(i -> i.id == "atomic", result.rubric_items))
        @test atomic_item.all_or_nothing
        @test !only(filter(i -> i.id == "partial", result.rubric_items)).all_or_nothing
        SkeletonizePackage._write_rubric(tmp, result.rubric_items)
        @test occursin("All-or-nothing scoring", read(joinpath(tmp, "RUBRIC.md"), String))
        @test isvalid(validate_reference_package(reference))

        strict = grade_submission(reference, submission; zero_on_failure=true, io=nothing)
        @test strict.total_awarded == 0
        @test occursin("ASSIGNMENT ZEROED", strict.student_report)
        @test occursin("GROUP MARKS ZEROED", strict.student_report)
        @test only(filter(c -> c.id == "atomic-met", strict.criterion_results)).passed
        @test first(strict.test_results).passed == first(result.test_results).passed
    end
end

@testset "oracle credit belongs to its recorded group" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp)
        write(joinpath(reference, "src", "Reference.jl"), "module Reference\nexport f\nf(x)=x\nend\n")
        write(joinpath(submission, "src", "Reference.jl"), "module Reference\nexport f\nf(x)=abs(x)\nend\n")
        write(joinpath(reference, "test", "runtests.jl"), """
using Reference, SkeletonizePackage, Test
@hidden_test begin
    @marks 3 "mixed oracle" id="mixed"
    @test true
    @reference_test f generator=[-1, 1]
end
@hidden_test begin
    @marks 2 "independent oracle" id="independent"
    @reference_test f generator=[1, 2]
end
@hidden_test begin
    @marks 2 "atomic oracle" id="atomic" all_or_nothing=true
    @reference_test f generator=[-1, 1]
end
""")
        result = grade_submission(reference, submission; io=nothing)
        by_id = Dict(c.id => c for c in result.criterion_results)
        @test by_id["mixed"].awarded == 2
        @test by_id["independent"].awarded == 2
        @test by_id["independent"].passed
        @test by_id["atomic"].awarded == 0
        @test !by_id["atomic"].passed
        @test result.total_awarded == 4
        @test length(unique(r.line for r in result.reference_test_results)) == 3
        oracle_criteria = filter(c -> c.kind == :reference_test, result.criterion_results)
        @test [c.passed for c in oracle_criteria] == [false, true, false]

        write(joinpath(reference, "test", "runtests.jl"), "using Reference, SkeletonizePackage\n@hidden_test begin\n @marks 2 \"oracle only\"\n @reference_test f generator=[1, 2]\nend\n")
        oracle_only = grade_submission(reference, submission; io=nothing)
        @test isvalid(oracle_only)
        @test oracle_only.total_awarded == 2
    end
end

@testset "completed groups retain credit on interrupted runs" begin
    mktempdir() do tmp
        reference, submission = _write_grade_fixture!(tmp)
        write(joinpath(reference, "test", "runtests.jl"), """
using Test
@hidden_test begin
    @marks 2 "completed" id="completed"
    @test true
end
@hidden_test begin
    @marks 2 "interrupted" id="interrupted"
    @test true
    exit(0)
end
@hidden_test begin
    @marks 2 "unreached" id="unreached"
    @test true
end
""")
        result = grade_submission(reference, submission; io=nothing)
        by_id = Dict(c.id => c for c in result.criterion_results)
        @test result.failure_category == :execution_failure
        @test by_id["completed"].awarded == 2
        @test by_id["interrupted"].awarded == 0
        @test by_id["unreached"].awarded == 0
        @test occursin("Review required", by_id["interrupted"].message)
    end
end

@testset "all-or-nothing annotation validation" begin
    parse_marks = SkeletonizePackage._parse_marks_line
    @test parse_marks("@marks 8 \"checks\"").all_or_nothing == false
    @test parse_marks("@marks 8 \"checks\" all_or_nothing=true").all_or_nothing
    @test !parse_marks("@marks 8 \"checks\" all_or_nothing=false").all_or_nothing
    @test parse_marks("@marks 8 \"checks\" all_or_nothing=1") === nothing
    @test parse_marks("@marks 8 \"checks\" all_or_nothing=\"true\"") === nothing
    @test parse_marks("@marks 8 \"checks\" zero_marks=true") === nothing
    item = SkeletonizePackage.RubricItem("old", :marks, :public, 2, "old constructor", false, nothing, "test.jl", 1)
    @test !item.all_or_nothing
    old_reference = ReferenceTestResult(:f, :hidden, 1, "1", "1", "1", true, "matched")
    @test isempty(old_reference.path)
    @test old_reference.line == 0
end

@testset "empty snapshot arrays have stable types" begin
    mktempdir() do tmp
        path = joinpath(tmp, "results.toml")
        write(path, """
[[tests]]
name = "oracle-only group"
status = "not_run"
passed = 0
failed = 0
errored = 0
broken = 0
details = []
marks = []
""")
        rows, error = SkeletonizePackage._read_behavioral_results(path)
        @test isempty(error)
        row = only(rows)
        @test row.details isa Vector{String}
        @test row.marks isa Vector{String}
        @test row.references isa Vector{String}
        @test !row.aborted
    end
end
