module SkeletonPackages

using TOML

export @solution, @starter, @student_test, @hidden_test,
       AssignmentConfig, GradeResult, ValidationIssue, ValidationReport,
       create_assignment, generate_student_package, grade_submission, main,
       read_assignment_config, strip_teacher_annotations, validate_teacher_package

"""
    @solution begin
        ...
    end

Mark a teacher-only implementation block.

`generate_student_package` removes this block from student packages. At runtime
inside the teacher package, the macro expands to its body so the reference
implementation remains executable.
"""
macro solution(block)
    return esc(block)
end

"""
    @starter begin
        ...
    end

Mark the starter code that students should receive in place of a teacher
solution.

`generate_student_package` keeps this block for student packages and removes it
from teacher-mode output. In the teacher package, the macro expands to `nothing`
so starter code does not run.
"""
macro starter(block)
    return :(nothing)
end

"""
    @student_test begin
        ...
    end

Mark tests that should be visible to students and also run for teachers.
"""
macro student_test(block)
    return esc(block)
end

"""
    @hidden_test begin
        ...
    end

Mark teacher-only grading tests. These tests are removed from student packages
but run normally in the annotated teacher package.
"""
macro hidden_test(block)
    return esc(block)
end

"""
    strip_teacher_annotations(text::AbstractString; mode=:student)

Transform annotated Julia source text.

For `mode = :student`, remove `@solution` and `@hidden_test` regions, and keep
the bodies of `@starter` and `@student_test` regions. For `mode = :teacher`,
keep `@solution`, `@student_test`, and `@hidden_test` bodies, and remove
`@starter` regions.

This implementation is intentionally line-oriented. Annotation macros must
appear on their own line as `@solution begin`, `@starter begin`,
`@student_test begin`, or `@hidden_test begin`.
"""
function strip_teacher_annotations(text::AbstractString; mode::Symbol=:student)
    lines = split(String(text), '\n'; keepempty=true)
    out = String[]
    i = 1
    while i <= length(lines)
        line = lines[i]
        stripped = strip(line)
        if stripped in ("@solution begin", "@starter begin", "@student_test begin", "@hidden_test begin")
            macro_name = split(stripped)[1]
            block, j = _collect_block(lines, i)
            if _keep_body(macro_name, mode)
                append!(out, block)
            end
            i = j + 1
        else
            push!(out, line)
            i += 1
        end
    end
    return join(out, "\n")
end

function _keep_body(macro_name::AbstractString, mode::Symbol)
    if mode == :student
        return macro_name in ("@starter", "@student_test")
    elseif mode == :teacher
        return macro_name in ("@solution", "@student_test", "@hidden_test")
    else
        throw(ArgumentError("mode must be :student or :teacher"))
    end
end

function _collect_block(lines, start_i)
    body = String[]
    depth = 1
    i = start_i + 1
    while i <= length(lines)
        s = strip(lines[i])
        if endswith(s, " begin") || occursin(r"\bbegin\b", s)
            depth += count(==("begin"), split(s))
        end
        if s == "end"
            depth -= 1
            if depth == 0
                return body, i
            end
        end
        push!(body, lines[i])
        i += 1
    end
    throw(ArgumentError("unterminated annotated block beginning at line $start_i"))
end

const ANNOTATION_OPENERS = Set(["@solution", "@starter", "@student_test", "@hidden_test"])
const TEACHER_ONLY_DIRS = Set([".git", "build", "solutions", ".julia", ".CondaPkg"])
const TRANSFORMED_EXTENSIONS = (".jl", ".md", ".toml")

"""
    ValidationIssue

A validation diagnostic for an annotated teacher package.

`severity` is `:error`, `:warning`, or `:info`. `path` is relative to the
validated package root when possible, and `line` is `nothing` for package-level
diagnostics.
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

The result returned by [`validate_teacher_package`](@ref).

Use `isvalid(report)` to check whether the package has blocking errors. Printing
the report gives a teacher-facing checklist of errors, warnings, and suggestions.
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
    AssignmentConfig

Configuration for generating a student package.

Use [`read_assignment_config`](@ref) or pass a `SkeletonPackages.toml` file to
[`generate_student_package`](@ref) to construct this from TOML.
"""
struct AssignmentConfig
    source_path::String
    student_path::String
    mode::Symbol
    force::Bool
    validate::Bool
end

"""
    read_assignment_config(path="SkeletonPackages.toml")

Read an assignment configuration file.

Expected TOML shape:

```toml
[assignment]
source_path = "examples/SortingAssignment"
student_path = "SortingAssignmentStudent"
mode = "student"
force = false
validate = true
```
"""
function read_assignment_config(path::AbstractString="SkeletonPackages.toml")
    data = TOML.parsefile(path)
    assignment = get(data, "assignment", Dict{String, Any}())
    base = dirname(abspath(path))
    source = get(assignment, "source_path", get(assignment, "source", ""))
    student = get(assignment, "student_path", get(assignment, "student_package", ""))
    isempty(source) && throw(ArgumentError("missing [assignment] source_path in $path"))
    isempty(student) && throw(ArgumentError("missing [assignment] student_path in $path"))
    mode = Symbol(get(assignment, "mode", "student"))
    force = Bool(get(assignment, "force", false))
    validate = Bool(get(assignment, "validate", true))
    return AssignmentConfig(_config_path(base, source), _config_path(base, student), mode, force, validate)
end

function _config_path(base::AbstractString, path::AbstractString)
    return isabspath(path) ? String(path) : normpath(joinpath(base, path))
end

"""
    validate_teacher_package(source_path; io=nothing)

Validate an annotated teacher package and return a [`ValidationReport`](@ref).

The validator checks for blocking transformation problems, such as unsupported
inline annotation forms and unterminated blocks. It also reports teaching-design
warnings, such as solution blocks without nearby starter blocks, missing public
tests, missing hidden tests, or starter code with no obvious TODO/error prompt.

Pass `io=stdout` to print a teacher-facing report while returning it.
"""
function validate_teacher_package(source_path::AbstractString; io::Union{Nothing, IO}=nothing)
    root = abspath(source_path)
    isdir(root) || throw(ArgumentError("source_path is not a directory: $source_path"))
    issues = ValidationIssue[]
    _validate_package_shape!(issues, root)
    annotation_counts = Dict(name => 0 for name in ANNOTATION_OPENERS)

    for (walkroot, dirs, files) in walkdir(root)
        filter!(d -> !(d in TEACHER_ONLY_DIRS), dirs)
        relroot = relpath(walkroot, root)
        for file in files
            path = joinpath(walkroot, file)
            rel = relroot == "." ? file : joinpath(relroot, file)
            _validate_file!(issues, annotation_counts, root, rel, path)
        end
    end

    if annotation_counts["@solution"] == 0
        _push_issue!(issues, :warning, "", nothing, "no @solution blocks found", "Add @solution blocks around teacher-only implementations.")
    end
    if annotation_counts["@starter"] == 0
        _push_issue!(issues, :warning, "", nothing, "no @starter blocks found", "Give students explicit starter code or placeholders for each exercise.")
    end
    if annotation_counts["@student_test"] == 0
        _push_issue!(issues, :warning, "", nothing, "no @student_test blocks found", "Include visible tests so students can check basic behaviour.")
    end
    if annotation_counts["@hidden_test"] == 0
        _push_issue!(issues, :info, "", nothing, "no @hidden_test blocks found", "Hidden tests are optional, but useful for grading edge cases.")
    end

    report = ValidationReport(root, issues)
    if io !== nothing
        show(io, report)
        println(io)
    end
    return report
end

function _validate_package_shape!(issues, root)
    isfile(joinpath(root, "Project.toml")) ||
        _push_issue!(issues, :error, "Project.toml", nothing, "missing Project.toml", "Create a normal Julia package before generating a student package.")
    isdir(joinpath(root, "src")) ||
        _push_issue!(issues, :error, "src", nothing, "missing src directory", "Put the annotated implementation under src/.")
    isdir(joinpath(root, "test")) ||
        _push_issue!(issues, :warning, "test", nothing, "missing test directory", "Add tests, including @student_test and optional @hidden_test blocks.")
end

function _validate_file!(issues, counts, root, rel, path)
    ext = splitext(path)[2]
    text = read(path, String)
    contains_annotation = any(occursin(name, text) for name in ANNOTATION_OPENERS)
    if contains_annotation && !(ext in TRANSFORMED_EXTENSIONS)
        _push_issue!(issues, :error, rel, nothing, "annotations appear in a file type that is copied without transformation", "Move annotations into .jl, .md, or .toml files, or extend the transformer.")
        return
    end
    ext in TRANSFORMED_EXTENSIONS || return

    lines = split(text, '\n'; keepempty=true)
    solution_lines = Int[]
    starter_lines = Int[]
    for (line_number, line) in enumerate(lines)
        stripped = strip(line)
        first_token = isempty(stripped) ? "" : first(split(stripped))
        if first_token in ANNOTATION_OPENERS
            counts[first_token] += 1
            if !(stripped in ("$first_token begin",))
                _push_issue!(issues, :error, rel, line_number, "unsupported annotation syntax: $stripped", "Put annotation openers on their own line, for example `$first_token begin`.")
            end
            first_token == "@solution" && push!(solution_lines, line_number)
            first_token == "@starter" && push!(starter_lines, line_number)
        elseif any(occursin(name, stripped) for name in ANNOTATION_OPENERS)
            _push_issue!(issues, :error, rel, line_number, "annotation appears inline or inside a larger expression", "Use a full block with the annotation opener on its own line.")
        elseif occursin(r"@(hidden|stub|student|teacher|hint|rubric)\b", stripped)
            _push_issue!(issues, :warning, rel, line_number, "unsupported planned annotation found", "Use the supported annotations: @solution, @starter, @student_test, and @hidden_test.")
        end
    end

    student_text = nothing
    teacher_text = nothing
    try
        student_text = strip_teacher_annotations(text; mode=:student)
        teacher_text = strip_teacher_annotations(text; mode=:teacher)
    catch err
        if err isa ArgumentError
            _push_issue!(issues, :error, rel, nothing, sprint(showerror, err), "Fix the annotated block structure before generating a student package.")
        else
            rethrow()
        end
    end

    if ext == ".jl" && student_text !== nothing && teacher_text !== nothing
        _validate_julia_syntax!(issues, rel, text, "teacher source")
        _validate_julia_syntax!(issues, rel, student_text, "student output")
        _validate_julia_syntax!(issues, rel, teacher_text, "teacher output")
    end

    for line in solution_lines
        if !any(abs(line - starter) <= 8 for starter in starter_lines)
            _push_issue!(issues, :warning, rel, line, "@solution has no nearby @starter block", "Pair each teacher solution with a student-facing starter block where practical.")
        end
    end

    for line in starter_lines
        block, _ = _collect_block(lines, line)
        starter_text = join(block, "\n")
        if !occursin(r"TODO|FIXME|error\(|throw\(|missing"i, starter_text)
            _push_issue!(issues, :info, rel, line, "@starter block has no obvious student prompt or failing placeholder", "Consider adding a TODO, `error(\"TODO\")`, or clear partial implementation.")
        end
    end
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

"""
    generate_student_package(source_path, dest_path; mode=:student, force=false, validate=true, io=stderr)
    generate_student_package(config::AssignmentConfig; io=stderr)
    generate_student_package(config_path::AbstractString; io=stderr)

Copy a Julia package from `source_path` to `dest_path`, transforming `.jl`, `.md`,
and `.toml` files by removing teacher-only annotated regions.

If `validate=true`, the teacher package is validated first. Validation errors
block generation; warnings and notes are printed to `io`.

Existing contents of `dest_path` are preserved unless `force=true`. The generated
path is returned. Directories named `.git`, `build`, and `solutions` are skipped.
"""
function generate_student_package(source_path::AbstractString, dest_path::AbstractString; mode::Symbol=:student, force::Bool=false, validate::Bool=true, io::Union{Nothing, IO}=stderr)
    src = abspath(source_path)
    dst = abspath(dest_path)
    isdir(src) || throw(ArgumentError("source_path is not a directory: $source_path"))
    if validate
        report = validate_teacher_package(src; io=io)
        isvalid(report) || throw(ArgumentError("teacher package validation failed; fix errors before generating"))
    end
    if ispath(dst)
        force || throw(ArgumentError("dest_path already exists: $dest_path (pass force=true to replace it)"))
        rm(dst; recursive=true, force=true)
    end
    mkpath(dst)
    for (root, dirs, files) in walkdir(src)
        filter!(d -> !(d in TEACHER_ONLY_DIRS), dirs)
        relroot = relpath(root, src)
        outroot = relroot == "." ? dst : joinpath(dst, relroot)
        mkpath(outroot)
        for file in files
            inpath = joinpath(root, file)
            outpath = joinpath(outroot, file)
            if endswith(file, ".jl") || endswith(file, ".md") || endswith(file, ".toml")
                text = read(inpath, String)
                write(outpath, strip_teacher_annotations(text; mode=mode))
            else
                cp(inpath, outpath; force=true)
            end
        end
    end
    _write_student_instructions(dst)
    return dst
end

function generate_student_package(config::AssignmentConfig; io::Union{Nothing, IO}=stderr)
    return generate_student_package(config.source_path, config.student_path; mode=config.mode, force=config.force, validate=config.validate, io=io)
end

function generate_student_package(config_path::AbstractString; io::Union{Nothing, IO}=stderr)
    return generate_student_package(read_assignment_config(config_path); io=io)
end

"""
    create_assignment(path; name=basename(path), force=false)

Create a small annotated teacher package template.

The template includes `Project.toml`, `src/`, `test/`, and a
`SkeletonPackages.toml` that can be used with `generate_student_package`.
"""
function create_assignment(path::AbstractString; name::AbstractString=basename(path), force::Bool=false)
    root = abspath(path)
    if ispath(root)
        force || throw(ArgumentError("assignment path already exists: $path (pass force=true to replace it)"))
        rm(root; recursive=true, force=true)
    end
    module_name = _module_name(name)
    uuid = string(Base.UUID(rand(UInt128)))
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    write(joinpath(root, "Project.toml"), """
name = "$module_name"
uuid = "$uuid"
version = "0.1.0"

[deps]
SkeletonPackages = "c8e6063d-6c4e-4aa4-bd9b-3a45f2ad7dd1"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
""")
    write(joinpath(root, "src", "$module_name.jl"), """
module $module_name

using SkeletonPackages

export answer

\"\"\"
    answer()

Return the answer for this assignment.
\"\"\"
function answer()
    @solution begin
        return 42
    end
    @starter begin
        error("TODO: implement answer")
    end
end

end
""")
    write(joinpath(root, "test", "runtests.jl"), """
using $module_name
using SkeletonPackages
using Test

@student_test begin
    @test answer() isa Integer
end

@hidden_test begin
    @test answer() == 42
end
""")
    write(joinpath(root, "SkeletonPackages.toml"), """
[assignment]
source_path = "."
student_path = "../$(module_name)Student"
mode = "student"
force = false
validate = true
""")
    return root
end

function _module_name(name)
    cleaned = replace(String(name), r"[^A-Za-z0-9_]" => "")
    isempty(cleaned) && throw(ArgumentError("name must contain at least one letter or digit"))
    occursin(r"^[A-Za-z_]", cleaned) ? cleaned : "Assignment$cleaned"
end

function _write_student_instructions(dst::AbstractString)
    package_name = _project_name(dst)
    write(joinpath(dst, "STUDENT_INSTRUCTIONS.md"), """
# Getting Started with `$package_name`

This is a Julia package skeleton for an assignment. Your job is to fill in the
starter code, run the tests, and submit the completed package as instructed by
your teacher.

## Package Layout

A standard Julia package usually has this structure:

```text
$package_name/
  Project.toml          package name, UUID, dependencies, and compatibility
  src/                  source code for the package
  test/                 tests you can run while working
  README.md             assignment-specific notes, if provided
```

Most assignments ask you to edit files under `src/`. Tests usually live in
`test/runtests.jl`. Do not change `Project.toml` unless the assignment or teacher
explicitly asks you to add dependencies.

## Opening Julia in the Package Environment

Open a terminal in this package directory. Then start Julia with the local package
environment active:

```bash
julia --project=.
```

Inside Julia, you can check that the active project is this folder:

```julia
using Pkg
Pkg.status()
```

## Installing Dependencies

The first time you use the package, install the dependencies recorded in
`Project.toml`:

```julia
using Pkg
Pkg.instantiate()
```

If your teacher asks you to add a package, activate this environment first, then
use:

```julia
using Pkg
Pkg.add("PackageName")
```

## Running Tests

From the terminal:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Or from inside Julia:

```julia
using Pkg
Pkg.test()
```

Tests are your fastest feedback loop. Run them after each small change.

## Editing and Reloading Code

Edit the files in `src/`, save them, and rerun the tests. If you are working in a
Julia session and want to try functions interactively, restart Julia after edits
or use a package such as Revise.jl if you already know it.

To load this package in the active environment:

```julia
using $package_name
```

## Common Problems

- `Package $package_name not found`: start Julia with `julia --project=.` from
  this package directory.
- Missing dependency errors: run `using Pkg; Pkg.instantiate()`.
- Tests still failing: read the first failing test and error message carefully,
  then work on the smallest function related to that failure.
- Changed the wrong environment: close Julia, return to this folder, and restart
  with `julia --project=.`

## Submitting

Before submitting, run the tests from a fresh Julia process:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Submit the completed package folder according to your teacher's instructions.
""")
end

function _project_name(path::AbstractString)
    project = joinpath(path, "Project.toml")
    if isfile(project)
        data = TOML.parsefile(project)
        return String(get(data, "name", basename(path)))
    end
    return basename(path)
end

"""
    grade_submission(reference_path, submission_path; test_path=nothing)

Run the first-pass grading harness for a student submission.

The current harness checks that `reference_path` and `submission_path` are
package directories, then runs `Pkg.test` for the submission in an isolated Julia
process. `test_path` is reserved for a future grading step that injects
teacher-provided hidden tests.
"""
function grade_submission(reference_path::AbstractString, submission_path::AbstractString; test_path=nothing)
    isdir(reference_path) || throw(ArgumentError("reference_path is not a directory"))
    isdir(submission_path) || throw(ArgumentError("submission_path is not a directory"))
    cmd = `$(Base.julia_cmd()) --project=$(submission_path) -e "using Pkg; Pkg.test()"`
    stdout_path = tempname()
    stderr_path = tempname()
    try
        proc = run(pipeline(cmd; stdout=stdout_path, stderr=stderr_path); wait=false)
        wait(proc)
        return GradeResult(success(proc), proc.exitcode, read(stdout_path, String), read(stderr_path, String))
    finally
        rm(stdout_path; force=true)
        rm(stderr_path; force=true)
    end
end

"""
    GradeResult

Result returned by [`grade_submission`](@ref).
"""
struct GradeResult
    passed::Bool
    exitcode::Int
    stdout::String
    stderr::String
end

Base.isvalid(result::GradeResult) = result.passed

function Base.show(io::IO, result::GradeResult)
    status = result.passed ? "passed" : "failed"
    print(io, "GradeResult(", status, ", exitcode=", result.exitcode, ")")
end

"""
    main(args=ARGS)

Command-line entry point.

Commands:

- `validate PATH`
- `generate SOURCE DEST [--force] [--no-validate]`
- `generate --config SkeletonPackages.toml [--force]`
- `init PATH [--name NAME] [--force]`
"""
function main(args=ARGS)
    isempty(args) && return _usage(stderr, 1)
    command = popfirst!(args)
    try
        if command == "validate"
            length(args) == 1 || return _usage(stderr, 1)
            report = validate_teacher_package(args[1]; io=stdout)
            return isvalid(report) ? 0 : 2
        elseif command == "generate"
            return _main_generate(args)
        elseif command in ("init", "create")
            return _main_init(args)
        else
            return _usage(stderr, 1)
        end
    catch err
        println(stderr, "error: ", sprint(showerror, err))
        return 1
    end
end

function _main_generate(args)
    force = _take_flag!(args, "--force")
    validate = !_take_flag!(args, "--no-validate")
    config_index = findfirst(==("--config"), args)
    if config_index !== nothing
        config_index < length(args) || throw(ArgumentError("--config requires a path"))
        config_path = args[config_index + 1]
        deleteat!(args, config_index:config_index + 1)
        isempty(args) || throw(ArgumentError("unexpected arguments: $(join(args, " "))"))
        config = read_assignment_config(config_path)
        config = AssignmentConfig(config.source_path, config.student_path, config.mode, force || config.force, validate && config.validate)
        println(generate_student_package(config; io=stderr))
        return 0
    end
    length(args) == 2 || return _usage(stderr, 1)
    println(generate_student_package(args[1], args[2]; force=force, validate=validate, io=stderr))
    return 0
end

function _main_init(args)
    force = _take_flag!(args, "--force")
    name = nothing
    name_index = findfirst(==("--name"), args)
    if name_index !== nothing
        name_index < length(args) || throw(ArgumentError("--name requires a value"))
        name = args[name_index + 1]
        deleteat!(args, name_index:name_index + 1)
    end
    length(args) == 1 || return _usage(stderr, 1)
    path = create_assignment(args[1]; name=something(name, basename(args[1])), force=force)
    println(path)
    return 0
end

function _take_flag!(args, flag)
    index = findfirst(==(flag), args)
    index === nothing && return false
    deleteat!(args, index)
    return true
end

function _usage(io, code)
    println(io, """
Usage:
  julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- validate PATH
  julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate SOURCE DEST [--force] [--no-validate]
  julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate --config SkeletonPackages.toml [--force]
  julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- init PATH [--name NAME] [--force]
""")
    return code
end

end # module
