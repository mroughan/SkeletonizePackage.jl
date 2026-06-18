"""
    main(args=ARGS)

Command-line entry point.

Commands:

- `validate PATH`
- `generate REFERENCE SKELETON [--force] [--no-validate] [--ai-policy forbidden|recorded|allowed]`
- `generate --config SkeletonizePackage.inc [--force]`
- `grade REFERENCE SUBMISSION [--student-id ID] [--report PATH] [--html PATH] [--gradescope PATH] [--csv PATH] [--csv-format default|canvas|moodle|blackboard] [--replace-csv] [--test-timeout N] [--ref-timeout N]`
- `init PATH [--name NAME] [--force] [--ai-policy forbidden|recorded|allowed]`

# Example

```julia
julia> main(["validate", "examples/SortingAssignment"])
0

julia> main(["generate", "examples/SortingAssignment", "SortingAssignmentSkeleton", "--force"])
0

julia> main([
           "grade",
           "examples/SortingAssignment",
           "SortingAssignmentSubmission",
           "--student-id",
           "s123",
           "--report",
           "s123-feedback.md",
           "--csv",
           "marks.csv",
       ])
0
```

The `grade` command prints output paths when `--report` or `--csv` is supplied:

```text
s123-feedback.md
marks.csv
```
"""
function main(args=ARGS)
    isempty(args) && return _usage(stderr, 1)
    command = popfirst!(args)
    try
        if command == "validate"
            length(args) == 1 || return _usage(stderr, 1)
            report = validate_reference_package(args[1]; io=stdout, run_tests=true)
            return isvalid(report) ? 0 : 2
        elseif command == "generate"
            return _main_generate(args)
        elseif command == "grade"
            return _main_grade(args)
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
    ai_policy = _take_ai_policy!(args)
    config_index = findfirst(==("--config"), args)
    if config_index !== nothing
        config_index < length(args) || throw(ArgumentError("--config requires a path"))
        config_path = args[config_index + 1]
        deleteat!(args, config_index:config_index + 1)
        isempty(args) || throw(ArgumentError("unexpected arguments: $(join(args, " "))"))
        config = read_assignment_config(config_path)
        config = AssignmentConfig(config.reference_path, config.skeleton_path, config.mode, force || config.force, validate && config.validate, config.instructions_path, something(ai_policy, config.ai_policy), config.copy_paths)
        println(generate_skeleton_package(config; io=stderr))
        return 0
    end
    length(args) == 2 || return _usage(stderr, 1)
    println(generate_skeleton_package(args[1], args[2]; force=force, validate=validate, ai_policy=something(ai_policy, :recorded), io=stderr))
    return 0
end

function _main_grade(args)
    replace_csv        = _take_flag!(args, "--replace-csv")
    student_id         = _take_option!(args, "--student-id")
    report_path        = _take_option!(args, "--report")
    html_path          = _take_option!(args, "--html")
    gradescope_path    = _take_option!(args, "--gradescope")
    csv_path           = _take_option!(args, "--csv")
    csv_format_str     = _take_option!(args, "--csv-format")
    test_timeout_str   = _take_option!(args, "--test-timeout")
    ref_timeout_str    = _take_option!(args, "--ref-timeout")
    length(args) == 2 || return _usage(stderr, 1)
    csv_format       = csv_format_str   === nothing ? :default : Symbol(csv_format_str)
    test_timeout     = test_timeout_str === nothing ? 120      : parse(Int, test_timeout_str)
    ref_timeout      = ref_timeout_str  === nothing ? 30       : parse(Int, ref_timeout_str)
    result = grade_submission(
        args[1],
        args[2];
        student_id=something(student_id, basename(abspath(args[2]))),
        report_path=report_path,
        html_path=html_path,
        gradescope_path=gradescope_path,
        csv_path=csv_path,
        csv_format=csv_format,
        append_csv=!replace_csv,
        test_timeout_seconds=test_timeout,
        reference_timeout_seconds=ref_timeout,
    )
    if report_path === nothing && html_path === nothing
        print(result.student_report)
    else
        report_path    === nothing || println(report_path)
        html_path      === nothing || println(html_path)
        gradescope_path === nothing || println(gradescope_path)
    end
    csv_path === nothing || println(csv_path)
    return isvalid(result) ? 0 : 2
end

function _main_init(args)
    force = _take_flag!(args, "--force")
    ai_policy = something(_take_ai_policy!(args), :recorded)
    name = nothing
    name_index = findfirst(==("--name"), args)
    if name_index !== nothing
        name_index < length(args) || throw(ArgumentError("--name requires a value"))
        name = args[name_index + 1]
        deleteat!(args, name_index:name_index + 1)
    end
    length(args) == 1 || return _usage(stderr, 1)
    path = create_assignment(args[1]; name=something(name, basename(args[1])), force=force, ai_policy=ai_policy)
    println(path)
    return 0
end

function _take_ai_policy!(args)
    value = _take_option!(args, "--ai-policy")
    value === nothing && return nothing
    return _metadata_ai_policy(value)
end

function _take_flag!(args, flag)
    index = findfirst(==(flag), args)
    index === nothing && return false
    deleteat!(args, index)
    return true
end

function _take_option!(args, option)
    index = findfirst(==(option), args)
    index === nothing && return nothing
    index < length(args) || throw(ArgumentError("$option requires a value"))
    value = args[index + 1]
    deleteat!(args, index:index + 1)
    return value
end

function _usage(io, code)
    println(io, """
Usage:
  julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- validate PATH
  julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- generate REFERENCE SKELETON [--force] [--no-validate] [--ai-policy forbidden|recorded|allowed]
  julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- generate --config SkeletonizePackage.inc [--force]
  julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- grade REFERENCE SUBMISSION [--student-id ID] [--report PATH] [--html PATH] [--gradescope PATH] [--csv PATH] [--csv-format default|canvas|moodle|blackboard] [--replace-csv] [--test-timeout N] [--ref-timeout N]
  julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- init PATH [--name NAME] [--force] [--ai-policy forbidden|recorded|allowed]
""")
    return code
end
