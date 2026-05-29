"""
    main(args=ARGS)

Command-line entry point.

Commands:

- `validate PATH`
- `generate SOURCE DEST [--force] [--no-validate]`
- `generate --config SkeletonPackages.inc [--force]`
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
        config = AssignmentConfig(config.source_path, config.student_path, config.mode, force || config.force, validate && config.validate, config.instructions_path)
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
  julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- generate --config SkeletonPackages.inc [--force]
  julia --project -e 'using SkeletonPackages; exit(SkeletonPackages.main())' -- init PATH [--name NAME] [--force]
""")
    return code
end
