"""
    GradeResult

Result returned by [`grade_submission`](@ref).
"""
struct GradeResult
    passed::Bool
    exitcode::Int
    stdout::String
    stderr::String
    student_id::String
    rubric_items::Vector{RubricItem}
    awarded_by_category::Dict{String, Int}
    possible_by_category::Dict{String, Int}
    total_awarded::Int
    total_possible::Int
    student_report::String
    csv_header::String
    csv_row::String
end

function GradeResult(passed::Bool, exitcode::Int, stdout::String, stderr::String)
    possible = Dict{String, Int}()
    awarded = Dict{String, Int}()
    total = 0
    header, row = _grade_csv(["student_id", "status", "total"], ["", passed ? "passed" : "failed", string(passed ? total : 0)])
    report = _student_grade_report("", passed, exitcode, RubricItem[], awarded, possible, passed ? total : 0, total, stdout, stderr)
    return GradeResult(passed, exitcode, stdout, stderr, "", RubricItem[], awarded, possible, passed ? total : 0, total, report, header, row)
end

Base.isvalid(result::GradeResult) = result.passed

function Base.show(io::IO, result::GradeResult)
    status = result.passed ? "passed" : "failed"
    print(io, "GradeResult(", status, ", exitcode=", result.exitcode, ")")
end

"""
    grade_submission(reference_path, submission_path; test_path=nothing, student_id=basename(submission_path), report_path=nothing, csv_path=nothing, append_csv=true)

Run the first-pass grading harness for a student submission package.

The current harness checks that `reference_path` and `submission_path` are
package directories, then runs `Pkg.test` for the submission in an isolated Julia
process. `test_path` is reserved for a future grading step that injects
teacher-provided hidden tests.

The result includes two grading outputs:

- `student_report`, a Markdown report intended for student feedback.
- `csv_header` and `csv_row`, a CSV-friendly mark summary suitable for
  concatenating one row per student.

Until hidden/reference test injection records per-rubric outcomes, marks are
awarded all-or-nothing from the submission test result. A passing submission gets
all rubric marks; a failing submission gets zero, with stdout and stderr
included in the report for diagnosis.
"""
function grade_submission(reference_path::AbstractString, submission_path::AbstractString; test_path=nothing, student_id::AbstractString=basename(abspath(submission_path)), report_path::Union{Nothing, AbstractString}=nothing, csv_path::Union{Nothing, AbstractString}=nothing, append_csv::Bool=true)
    isdir(reference_path) || throw(ArgumentError("reference_path is not a directory"))
    isdir(submission_path) || throw(ArgumentError("submission_path is not a directory"))
    test_path === nothing || ispath(test_path) || throw(ArgumentError("test_path does not exist"))

    rubric = _collect_rubric(reference_path)
    cmd = `$(Base.julia_cmd()) --project=$(submission_path) -e "using Pkg; Pkg.test()"`
    stdout_path = tempname()
    stderr_path = tempname()
    try
        proc = run(pipeline(cmd; stdout=stdout_path, stderr=stderr_path); wait=false)
        wait(proc)
        stdout = read(stdout_path, String)
        stderr = read(stderr_path, String)
        passed = success(proc)
        possible = _rubric_points_by_category(rubric)
        awarded = passed ? copy(possible) : Dict(category => 0 for category in keys(possible))
        total_possible = sum(values(possible); init=0)
        total_awarded = sum(values(awarded); init=0)
        categories = sort(collect(keys(possible)))
        header_values = vcat(["student_id", "status"], categories, ["total"])
        row_values = vcat([String(student_id), passed ? "passed" : "failed"], [string(get(awarded, category, 0)) for category in categories], [string(total_awarded)])
        header, row = _grade_csv(header_values, row_values)
        report = _student_grade_report(String(student_id), passed, proc.exitcode, rubric, awarded, possible, total_awarded, total_possible, stdout, stderr)
        result = GradeResult(passed, proc.exitcode, stdout, stderr, String(student_id), rubric, awarded, possible, total_awarded, total_possible, report, header, row)
        report_path === nothing || write(report_path, report)
        csv_path === nothing || _write_grade_csv(csv_path, header, row; append=append_csv)
        return result
    finally
        rm(stdout_path; force=true)
        rm(stderr_path; force=true)
    end
end

function _rubric_points_by_category(items::Vector{RubricItem})
    points = Dict{String, Int}()
    for item in items
        item.kind == :marks || continue
        category = String(item.visibility)
        points[category] = get(points, category, 0) + item.points
    end
    return points
end

function _student_grade_report(student_id::AbstractString, passed::Bool, exitcode::Int, rubric::Vector{RubricItem}, awarded::Dict{String, Int}, possible::Dict{String, Int}, total_awarded::Int, total_possible::Int, stdout::String, stderr::String)
    io = IOBuffer()
    println(io, "# Student Feedback Report")
    println(io)
    isempty(student_id) || println(io, "Student: `", student_id, "`")
    println(io, "Status: ", passed ? "passed" : "failed")
    println(io, "Exit code: ", exitcode)
    println(io, "Total: ", total_awarded, " / ", total_possible, " marks")
    println(io)
    println(io, "## Mark Summary")
    categories = sort(collect(keys(possible)))
    if isempty(categories)
        println(io)
        println(io, "No marked rubric criteria were found in the reference package.")
    else
        println(io)
        for category in categories
            println(io, "- ", category, ": ", get(awarded, category, 0), " / ", possible[category])
        end
    end
    println(io)
    println(io, "## Rubric Results")
    marks = [item for item in rubric if item.kind == :marks]
    if isempty(marks)
        println(io)
        println(io, "No marked criteria were available.")
    else
        for item in marks
            item_awarded = passed ? item.points : 0
            println(io)
            println(io, "- [", item.visibility, "] ", item.description, ": ", item_awarded, " / ", item.points, " mark", item.points == 1 ? "" : "s")
        end
    end
    properties = [item for item in rubric if item.kind != :marks]
    if !isempty(properties)
        println(io)
        println(io, "## Code Properties")
        for item in properties
            println(io)
            println(io, "- [", item.visibility, "] ", item.description)
        end
    end
    println(io)
    println(io, "## Test Output")
    if isempty(strip(stdout)) && isempty(strip(stderr))
        println(io)
        println(io, "No test output was captured.")
    else
        if !isempty(strip(stdout))
            println(io)
            println(io, "### stdout")
            println(io)
            println(io, "```text")
            print(io, rstrip(stdout))
            println(io)
            println(io, "```")
        end
        if !isempty(strip(stderr))
            println(io)
            println(io, "### stderr")
            println(io)
            println(io, "```text")
            print(io, rstrip(stderr))
            println(io)
            println(io, "```")
        end
    end
    println(io)
    println(io, "_Per-criterion marks are currently inferred from the overall submission test result._")
    return String(take!(io))
end

function _grade_csv(header_values::Vector{String}, row_values::Vector{String})
    header = join(_csv_escape.(header_values), ",")
    row = join(_csv_escape.(row_values), ",")
    return header, row
end

function _csv_escape(value::AbstractString)
    needs_quotes = any(ch -> ch in (',', '"', '\n', '\r'), value)
    escaped = replace(value, "\"" => "\"\"")
    return needs_quotes ? "\"$escaped\"" : escaped
end

function _write_grade_csv(path::AbstractString, header::AbstractString, row::AbstractString; append::Bool)
    should_write_header = !append || !isfile(path) || filesize(path) == 0
    open(path, append ? "a" : "w") do io
        should_write_header && println(io, header)
        println(io, row)
    end
    return path
end
