# Maximum gap between the end of one annotation block and the start of its pair.
# Comparing block edges avoids false warnings for long solution implementations.
const _SCAFFOLDING_PROXIMITY_LINES = 3

# Patterns that indicate a scaffolding block already contains a student prompt or
# failing placeholder, so no warning is needed.
const _RE_SCAFFOLDING_PROMPT = r"TODO|FIXME|error\(|throw\(|\bmissing\b|unimplemented"i

"""
    ValidationIssue

A validation diagnostic for an annotated teacher reference package.

`severity` is `:error`, `:warning`, or `:info`. `path` is relative to the
validated package root when possible, and `line` is `nothing` for package-level
diagnostics.

# Example

```julia
julia> issue = ValidationIssue(:warning, "test/runtests.jl", 3, "no @student_test blocks found", "Add visible tests.");

julia> sprint(show, issue)
"WARNING test/runtests.jl:3: no @student_test blocks found\\n  suggestion: Add visible tests."
```
"""
struct ValidationIssue
    severity::Symbol
    path::String
    line::Union{Nothing, Int}
    message::String
    suggestion::String
end

"""
    ValidationReport

The result returned by [`validate_reference_package`](@ref).

Use `isvalid(report)` to check whether the package has blocking errors. Printing
the report gives a teacher-facing checklist of errors, warnings, and suggestions.

# Example

```julia
julia> report = ValidationReport("Reference", ValidationIssue[]);

julia> isvalid(report)
true

julia> sprint(show, report)
"Validation report for Reference\\n0 errors, 0 warnings, 0 notes\\nNo issues found."
```
"""
struct ValidationReport
    root::String
    issues::Vector{ValidationIssue}
end

Base.isvalid(report::ValidationReport) = !any(issue -> issue.severity == :error, report.issues)

function Base.show(io::IO, issue::ValidationIssue)
    loc = isempty(issue.path) ? "package" : issue.path
    if issue.line !== nothing
        loc *= ":$(issue.line)"
    end
    print(io, uppercase(String(issue.severity)), " ", loc, ": ", issue.message)
    if !isempty(issue.suggestion)
        print(io, "\n  suggestion: ", issue.suggestion)
    end
end

function Base.show(io::IO, report::ValidationReport)
    counts = Dict(level => count(issue -> issue.severity == level, report.issues) for level in (:error, :warning, :info))
    print(io, "Validation report for ", report.root, "\n")
    print(io, counts[:error], " errors, ", counts[:warning], " warnings, ", counts[:info], " notes")
    if isempty(report.issues)
        print(io, "\nNo issues found.")
    else
        for issue in report.issues
            print(io, "\n\n")
            show(io, issue)
        end
    end
end

"""
    validate_reference_package(reference_path; io=nothing, run_tests=false)

Validate an annotated teacher reference package and return a [`ValidationReport`](@ref).

The validator checks for blocking transformation problems, such as unsupported
inline annotation forms, unterminated blocks, package/module naming mismatches,
and grading requirements placed in package source. It also reports
teaching-design warnings, such as unreachable annotated source, solution blocks
without nearby scaffolding blocks, missing public tests, missing hidden tests,
or scaffolding code with no obvious TODO/error prompt.

Pass `run_tests=true` to execute the reference package's public and hidden
behavioural tests in a fresh Julia process. Failures and timeouts are warnings,
because environment setup can also prevent test execution. Requirements are
grading metadata and are not executed as behavioural tests.

Pass `io=stdout` to print a teacher-facing report while returning it. Generation
and the CLI `validate` command enable `run_tests=true` automatically.

# Example

```julia
julia> report = validate_reference_package("examples/SortingAssignment");

julia> isvalid(report)
true

julia> startswith(sprint(show, report), "Validation report")
true
```

With `io=stdout`, a report is printed as well as returned:

```text
Validation report for /path/to/examples/SortingAssignment
0 errors, 0 warnings, 0 notes
No issues found.
```
"""
function validate_reference_package(reference_path::AbstractString; io::Union{Nothing, IO}=nothing, run_tests::Bool=false)
    root = abspath(reference_path)
    isdir(root) || throw(ArgumentError("reference_path is not a directory: $reference_path"))
    issues = ValidationIssue[]
    _validate_package_shape!(issues, root)
    _validate_source_wiring!(issues, root)
    annotation_counts = Dict(name => 0 for name in ANNOTATION_OPENERS)

    for (walkroot, dirs, files) in walkdir(root)
        filter!(d -> !(d in TEACHER_ONLY_DIRS), dirs)
        relroot = relpath(walkroot, root)
        for file in files
            _is_teacher_only_file(file) && continue
            path = joinpath(walkroot, file)
            rel = relroot == "." ? file : joinpath(relroot, file)
            _validate_file!(issues, annotation_counts, rel, path)
        end
    end

    if annotation_counts["@solution"] == 0
        _push_issue!(issues, :warning, "", nothing, "no @solution blocks found", "Add @solution blocks around teacher-only implementations.")
    end
    if annotation_counts["@scaffolding"] == 0
        _push_issue!(issues, :warning, "", nothing, "no @scaffolding blocks found", "Give students explicit scaffolding code or placeholders for each exercise.")
    end
    if annotation_counts["@student_test"] == 0
        _push_issue!(issues, :warning, "", nothing, "no @student_test blocks found", "Include visible tests so students can check basic behaviour.")
    end
    if annotation_counts["@hidden_test"] == 0
        _push_issue!(issues, :info, "", nothing, "no @hidden_test blocks found", "Hidden tests are optional, but useful for grading edge cases.")
    end
    run_tests && _validate_reference_tests!(issues, root)

    report = ValidationReport(root, issues)
    if io !== nothing
        show(io, report)
        println(io)
    end
    return report
end

function _validate_reference_tests!(issues, root)
    test_path = joinpath(root, "test", "runtests.jl")
    isfile(test_path) || return
    project_name = _project_name(root)
    main_path = joinpath(root, "src", "$project_name.jl")
    isfile(main_path) || return

    script = """
    using SkeletonizePackage
    using Test
    Base.include(Main, $(repr(main_path)))
    test_text = read($(repr(test_path)), String)
    test_text = replace(test_text, Regex("\\\\busing\\\\s+$( _regex_escape(project_name) )\\\\b") => "using .$project_name")
    Base.include_string(Main, test_text, $(repr(test_path)))
    """
    stdout_path = tempname()
    stderr_path = tempname()
    try
        cmd = `$(Base.julia_cmd()) --startup-file=no -e $script`
        proc, timed_out = _run_with_timeout(cmd, stdout_path, stderr_path; timeout_seconds=120)
        success(proc) && !timed_out && return
        output = strip(read(stdout_path, String) * "\n" * read(stderr_path, String))
        summary = _last_nonempty_line(output)
        message = timed_out ? "reference behavioural tests timed out" : "reference behavioural tests failed"
        suggestion = isempty(summary) ?
            "Run the reference tests and fix failing @student_test or @hidden_test behaviour." :
            "Run the reference tests and fix failing behaviour. Last output: $summary"
        _push_issue!(issues, :warning, "test/runtests.jl", nothing, message, suggestion)
    catch err
        _push_issue!(issues, :warning, "test/runtests.jl", nothing, "reference behavioural tests could not be run", sprint(showerror, err))
    finally
        rm(stdout_path; force=true)
        rm(stderr_path; force=true)
    end
end

function _last_nonempty_line(text::AbstractString)
    lines = filter(!isempty, strip.(split(text, '\n')))
    isempty(lines) && return ""
    return last(lines)
end

"""
    _validate_package_shape!(issues, root)

Check that `root` contains the minimum files expected of a Julia package
(`Project.toml`, `src/`, `test/`). Pushes `ValidationIssue`s into `issues`.
"""
function _validate_package_shape!(issues, root)
    isfile(joinpath(root, "Project.toml")) ||
        _push_issue!(issues, :error, "Project.toml", nothing, "missing Project.toml", "Create a normal Julia package before generating a skeleton package.")
    isdir(joinpath(root, "src")) ||
        _push_issue!(issues, :error, "src", nothing, "missing src directory", "Put the annotated implementation under src/.")
    isdir(joinpath(root, "test")) ||
        _push_issue!(issues, :warning, "test", nothing, "missing test directory", "Add tests, including @student_test and optional @hidden_test blocks.")
end

function _validate_source_wiring!(issues, root)
    project_path = joinpath(root, "Project.toml")
    isfile(project_path) || return
    project = try
        TOML.parsefile(project_path)
    catch
        return
    end
    name = get(project, "name", nothing)
    name isa AbstractString || return
    main_path = joinpath(root, "src", "$name.jl")
    if !isfile(main_path)
        _push_issue!(issues, :error, "src/$name.jl", nothing, "package entry-point file does not match the Project.toml name", "Create `src/$name.jl` or correct the package name.")
        return
    end

    main_text = read(main_path, String)
    occursin(Regex("\\bmodule\\s+" * _regex_escape(name) * "\\b"), main_text) ||
        _push_issue!(issues, :error, "src/$name.jl", nothing, "package module does not match the Project.toml name", "Declare `module $name` in the package entry-point file.")

    reachable = _reachable_source_files(main_path)
    src_root = joinpath(root, "src")
    for (walkroot, _, files) in walkdir(src_root)
        for file in files
            endswith(file, ".jl") || continue
            path = joinpath(walkroot, file)
            path in reachable && continue
            text = read(path, String)
            any(occursin(annotation, text) for annotation in ANNOTATION_OPENERS) || continue
            rel = relpath(path, root)
            _push_issue!(issues, :warning, rel, nothing, "annotated source file is not reachable from the package entry point", "Include this file from `src/$name.jl` if its scaffolded functions belong to the assignment.")
        end
    end
end

_regex_escape(text::AbstractString) = replace(String(text), r"([\\.^$|?*+(){}\[\]])" => s"\\\1")

function _reachable_source_files(main_path)
    reachable = Set{String}()
    pending = [normpath(main_path)]
    while !isempty(pending)
        path = pop!(pending)
        path in reachable && continue
        isfile(path) || continue
        push!(reachable, path)
        text = read(path, String)
        for m in eachmatch(r"\binclude\(\s*\"([^\"]+\.jl)\"\s*\)", text)
            push!(pending, normpath(joinpath(dirname(path), m.captures[1])))
        end
    end
    return reachable
end

"""
    _validate_file!(issues, counts, rel, path)

Validate one file from the reference package. Updates `counts` for each annotation opener
found, and pushes `ValidationIssue`s into `issues` for unsupported syntax, syntax errors
after annotation stripping, unpaired solution blocks, and empty scaffolding prompts.
`rel` is the path relative to the package root (used in issue messages); `path` is absolute.
"""
function _validate_file!(issues, counts, rel, path)
    ext = splitext(path)[2]
    text = read(path, String)
    contains_annotation = any(occursin(name, text) for name in ANNOTATION_OPENERS)
    if contains_annotation && !(ext in TRANSFORMED_EXTENSIONS)
        _push_issue!(issues, :error, rel, nothing, "annotations appear in a file type that is copied without transformation", "Move annotations into .jl, .md, .toml, or .inc files, or extend the transformer.")
        return
    end
    ext in TRANSFORMED_EXTENSIONS || return

    lines = split(text, '\n'; keepempty=true)
    solution_blocks = Tuple{Int, Int}[]
    scaffolding_blocks = Tuple{Int, Int}[]
    for (line_number, line) in enumerate(lines)
        stripped = strip(line)
        first_token = isempty(stripped) ? "" : first(split(stripped))
        if first_token in ANNOTATION_OPENERS
            counts[first_token] += 1
            if !(stripped in ("$first_token begin",))
                _push_issue!(issues, :error, rel, line_number, "unsupported annotation syntax: $stripped", "Put annotation openers on their own line, for example `$first_token begin`.")
            end
            if first_token in ("@solution", "@scaffolding") && stripped == "$first_token begin"
                block_end = try
                    last(_collect_block(lines, line_number))
                catch err
                    err isa ArgumentError || rethrow()
                    line_number
                end
                block = (line_number, block_end)
                first_token == "@solution" ? push!(solution_blocks, block) : push!(scaffolding_blocks, block)
            end
            if first_token in ("@student_test", "@hidden_test") && stripped == "$first_token begin"
                block = try
                    first(_collect_block(lines, line_number))
                catch err
                    err isa ArgumentError || rethrow()
                    String[]
                end
                mark_count = count(line -> _parse_marks_line(strip(line)) !== nothing, block)
                mark_count > 1 &&
                    _push_issue!(issues, :info, rel, line_number, "$first_token block contains multiple @marks criteria", "Prefer one marked criterion per test block so the generated testset and feedback have a clear purpose.")
            end
        elseif startswith(stripped, "@marks")
            _parse_marks_line(stripped) === nothing &&
                _push_issue!(issues, :error, rel, line_number, "unsupported @marks syntax: $stripped", "Use `@marks POINTS \"student-facing description\"`, optionally with `id=\"stable-id\"`.")
        elseif startswith(stripped, "@require") || startswith(stripped, "@forbid")
            _parse_property_line(stripped) === nothing &&
                _push_issue!(issues, :error, rel, line_number, "unsupported requirement syntax: $stripped", "Use `@require property(...)`, optionally followed by `marks=N`, `zero_marks=true`, `id=\"stable-id\"`, and a description string.")
        elseif startswith(stripped, "@assignment_requirements")
            stripped == "@assignment_requirements begin" ||
                _push_issue!(issues, :error, rel, line_number, "unsupported assignment requirements syntax: $stripped", "Use `@assignment_requirements begin`.")
            _is_src_path(rel) &&
                _push_issue!(issues, :error, rel, line_number, "@assignment_requirements appears in package source", "Move grading requirements to `test/runtests.jl`; source-level requirements can break package loading.")
        elseif startswith(stripped, "@reference_test")
            _parse_reference_test_line(stripped) === nothing &&
                _push_issue!(issues, :error, rel, line_number, "unsupported reference test syntax: $stripped", "Use `@reference_test function_name generator=...`.")
        elseif any(occursin(name, stripped) for name in ANNOTATION_OPENERS)
            _push_issue!(issues, :error, rel, line_number, "annotation appears inline or inside a larger expression", "Use a full block with the annotation opener on its own line.")
        elseif occursin(r"@(hidden|stub|student|teacher|hint|rubric)\b", stripped)
                _push_issue!(issues, :warning, rel, line_number, "unsupported planned annotation found", "Use the supported annotations: @solution, @scaffolding, @student_test, @hidden_test, and @marks.")
        end
    end

    student_text = nothing
    teacher_text = nothing
    try
        student_text = strip_reference_annotations(text; mode=:student, testsets=ext == ".jl")
        teacher_text = strip_reference_annotations(text; mode=:teacher, testsets=ext == ".jl")
    catch err
        if err isa ArgumentError
            _push_issue!(issues, :error, rel, nothing, sprint(showerror, err), "Fix the annotated block structure before generating a skeleton package.")
        else
            rethrow()
        end
    end

    if ext == ".jl" && student_text !== nothing && teacher_text !== nothing
        _validate_julia_syntax!(issues, rel, text, "teacher source")
        _validate_julia_syntax!(issues, rel, student_text, "student output")
        _validate_julia_syntax!(issues, rel, teacher_text, "teacher output")
    end

    for solution in solution_blocks
        if !any(_annotation_blocks_near(solution, scaffolding) for scaffolding in scaffolding_blocks)
            _push_issue!(issues, :warning, rel, first(solution), "@solution has no nearby @scaffolding block", "Pair each reference solution with a student-facing scaffolding block where practical.")
        end
    end

    for (line, _) in scaffolding_blocks
        block = try
            first(_collect_block(lines, line))
        catch err
            err isa ArgumentError || rethrow()
            continue
        end
        scaffolding_text = join(block, "\n")
        if !occursin(_RE_SCAFFOLDING_PROMPT, scaffolding_text)
            _push_issue!(issues, :info, rel, line, "@scaffolding block has no obvious student prompt or failing placeholder", "Consider adding a TODO, `error(\"TODO\")`, or clear partial implementation.")
        end
    end
end

_is_src_path(rel::AbstractString) = startswith(rel, "src/") || startswith(rel, "src\\")

function _annotation_blocks_near(a::Tuple{Int, Int}, b::Tuple{Int, Int})
    a_start, a_end = a
    b_start, b_end = b
    gap = a_end < b_start ? b_start - a_end - 1 :
          b_end < a_start ? a_start - b_end - 1 : 0
    return gap <= _SCAFFOLDING_PROXIMITY_LINES
end

function _validate_julia_syntax!(issues, rel, text, label)
    parsed = Meta.parse("begin\n$text\nend"; raise=false)
    if parsed isa Expr && parsed.head == :error
        _push_issue!(issues, :error, rel, nothing, "$label does not parse as Julia code", "Check that annotation removal leaves complete expressions and balanced blocks.")
    end
end

function _push_issue!(issues, severity, path, line, message, suggestion)
    push!(issues, ValidationIssue(severity, String(path), line, String(message), String(suggestion)))
end
