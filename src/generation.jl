"""
    generate_skeleton_package(reference_path, skeleton_path; mode=:student, force=false, validate=true, instructions_path=nothing, io=stderr)
    generate_student_package(config::AssignmentConfig; io=stderr)
    generate_student_package(config_path::AbstractString; io=stderr)

Transform a teacher reference package at `reference_path` into a student
skeleton package at `skeleton_path`, rewriting `.jl`, `.md`, `.toml`, and `.inc`
files by removing teacher-only annotated regions.

If `validate=true`, the teacher package is validated first. Validation errors
block generation; warnings and notes are printed to `io`.

Existing contents of `skeleton_path` are preserved unless `force=true`. The
generated path is returned. Directories named `.git`, `build`, and `solutions`
are skipped.

Pass `instructions_path` to append exercise-specific teacher instructions to the
generated `STUDENT_INSTRUCTIONS.md`. Relative paths in `SkeletonPackages.inc`
are resolved from the config file's directory.
"""
function generate_skeleton_package(reference_path::AbstractString, skeleton_path::AbstractString; mode::Symbol=:student, force::Bool=false, validate::Bool=true, instructions_path::Union{Nothing, AbstractString}=nothing, io::Union{Nothing, IO}=stderr)
    reference = abspath(reference_path)
    skeleton = abspath(skeleton_path)
    isdir(reference) || throw(ArgumentError("reference_path is not a directory: $reference_path"))
    if validate
        report = validate_teacher_package(reference; io=io)
        isvalid(report) || throw(ArgumentError("reference package validation failed; fix errors before generating"))
    end
    if ispath(skeleton)
        force || throw(ArgumentError("skeleton_path already exists: $skeleton_path (pass force=true to replace it)"))
        rm(skeleton; recursive=true, force=true)
    end
    mkpath(skeleton)
    rubric = _collect_rubric(reference)
    for (root, dirs, files) in walkdir(reference)
        filter!(d -> !(d in TEACHER_ONLY_DIRS), dirs)
        relroot = relpath(root, reference)
        outroot = relroot == "." ? skeleton : joinpath(skeleton, relroot)
        mkpath(outroot)
        for file in files
            inpath = joinpath(root, file)
            outpath = joinpath(outroot, file)
            if any(ext -> endswith(file, ext), TRANSFORMED_EXTENSIONS)
                text = read(inpath, String)
                write(outpath, strip_teacher_annotations(text; mode=mode))
            else
                cp(inpath, outpath; force=true)
            end
        end
    end
    _write_student_instructions(skeleton; instructions_path=instructions_path)
    _write_rubric(skeleton, rubric)
    return skeleton
end

"""
    generate_student_package(args...; kwargs...)

Backward-compatible alias for [`generate_skeleton_package`](@ref).
"""
function generate_student_package(reference_path::AbstractString, skeleton_path::AbstractString; kwargs...)
    return generate_skeleton_package(reference_path, skeleton_path; kwargs...)
end

function generate_student_package(config::AssignmentConfig; io::Union{Nothing, IO}=stderr)
    return generate_skeleton_package(config.source_path, config.student_path; mode=config.mode, force=config.force, validate=config.validate, instructions_path=config.instructions_path, io=io)
end

function generate_student_package(config_path::AbstractString; io::Union{Nothing, IO}=stderr)
    return generate_student_package(read_assignment_config(config_path); io=io)
end
