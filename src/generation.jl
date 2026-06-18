"""
    generate_skeleton_package(reference_path, skeleton_path; mode=:student, force=false, validate=true, instructions_path=nothing, ai_policy=:recorded, copy_paths=DEFAULT_COPY_PATHS, io=stderr)
    generate_skeleton_package(config::AssignmentConfig; io=stderr)
    generate_skeleton_package(config_path::AbstractString; io=stderr)

Transform a teacher reference package at `reference_path` into a student
skeleton package at `skeleton_path`, rewriting copied `.jl`, `.md`, `.toml`,
and `.inc` files by removing teacher-only annotated regions.

If `validate=true`, the reference package is validated first. Validation errors
block generation; warnings and notes are printed to `io`.

Existing contents of `skeleton_path` are preserved unless `force=true`. The
generated path is returned. By default, generation copies `Project.toml`,
`SkeletonizePackage.inc`, and the `src`, `test`, and `data` directories when
they exist. Pass `copy_paths` to opt in any additional files or directories.
Directories named `.git`, `build`, and `solutions` are skipped, along with
common editor backup files ending in `~` or wrapped in `#...#`, and Julia
coverage/allocation artifacts ending in `.cov` or `.mem`.

Pass `instructions_path` to append exercise-specific teacher instructions to the
generated `STUDENT_INSTRUCTIONS.md`. If it is omitted and `student_notes.md`
exists in the reference root, that file is included automatically. Relative
paths in `SkeletonizePackage.inc` are resolved from the config file's directory.

Every generated skeleton includes an `AGENTS.md` file. Set `ai_policy` to
`:forbidden`, `:recorded`, or `:allowed` to control the student-facing AI-agent
instructions. Student-mode generation also writes a skeleton-specific
`README.md`, generated `RUBRIC.md`, and named testsets for public test blocks.

# Example

```julia
julia> skeleton = generate_skeleton_package(
           "examples/SortingAssignment",
           "SortingAssignmentSkeleton";
           force=true,
           io=nothing,
       );

julia> basename(skeleton)
"SortingAssignmentSkeleton"

julia> isfile(joinpath(skeleton, "RUBRIC.md"))
true

julia> isfile(joinpath(skeleton, "STUDENT_INSTRUCTIONS.md"))
true
```

From a config file:

```julia
julia> skeleton = generate_skeleton_package("examples/ConfiguredAssignment/SkeletonizePackage.inc"; io=nothing);

julia> endswith(skeleton, "ConfiguredAssignmentStudent")
true
```
"""
function generate_skeleton_package(reference_path::AbstractString, skeleton_path::AbstractString; mode::Symbol=:student, force::Bool=false, validate::Bool=true, instructions_path::Union{Nothing, AbstractString}=nothing, ai_policy::Symbol=:recorded, copy_paths=DEFAULT_COPY_PATHS, io::Union{Nothing, IO}=stderr)
    reference = abspath(reference_path)
    skeleton = abspath(skeleton_path)
    policy = _metadata_ai_policy(ai_policy)
    copied = _metadata_copy_paths(copy_paths)
    isdir(reference) || throw(ArgumentError("reference_path is not a directory: $reference_path"))
    if validate
        report = validate_reference_package(reference; io=io, run_tests=true)
        isvalid(report) || throw(ArgumentError("reference package validation failed; fix errors before generating"))
    end
    if ispath(skeleton)
        force || throw(ArgumentError("skeleton_path already exists: $skeleton_path (pass force=true to replace it)"))
        rm(skeleton; recursive=true, force=true)
    end
    mkpath(skeleton)
    rubric = _collect_rubric(reference)
    # Absolutize once so the skip-during-copy check and the actual read are consistent,
    # regardless of any working-directory change between the two points.
    instructions_abs = _default_instructions_path(reference, instructions_path)
    for (root, dirs, files) in walkdir(reference)
        relroot = relpath(root, reference)
        filter!(dirs) do dir
            !(dir in TEACHER_ONLY_DIRS) &&
                _should_descend_for_copy(_reljoin(relroot, dir), copied)
        end
        outroot = relroot == "." ? skeleton : joinpath(skeleton, relroot)
        for file in files
            _is_teacher_only_file(file) && continue
            relfile = _reljoin(relroot, file)
            _should_copy_path(relfile, copied) || continue
            inpath = joinpath(root, file)
            instructions_abs !== nothing && abspath(inpath) == instructions_abs && continue
            mkpath(outroot)
            outpath = joinpath(outroot, file)
            if any(ext -> endswith(file, ext), TRANSFORMED_EXTENSIONS)
                text = read(inpath, String)
                write(outpath, strip_reference_annotations(text; mode=mode, testsets=endswith(file, ".jl")))
            else
                cp(inpath, outpath; force=true)
            end
        end
    end
    _write_student_instructions(skeleton; instructions_path=instructions_abs)
    _write_agents_file(skeleton; ai_policy=policy)
    _write_rubric(skeleton, rubric)
    mode == :student && _write_student_readme(skeleton)
    return skeleton
end

function generate_skeleton_package(config::AssignmentConfig; io::Union{Nothing, IO}=stderr)
    return generate_skeleton_package(config.reference_path, config.skeleton_path; mode=config.mode, force=config.force, validate=config.validate, instructions_path=config.instructions_path, ai_policy=config.ai_policy, copy_paths=config.copy_paths, io=io)
end

function generate_skeleton_package(config_path::AbstractString; io::Union{Nothing, IO}=stderr)
    return generate_skeleton_package(read_assignment_config(config_path); io=io)
end

function _reljoin(root::AbstractString, name::AbstractString)
    rel = root == "." ? String(name) : joinpath(root, name)
    return replace(normpath(rel), '\\' => '/')
end

function _should_copy_path(relpath::AbstractString, copy_paths)
    rel = replace(normpath(relpath), '\\' => '/')
    return any(copy_path -> rel == copy_path || startswith(rel, copy_path * "/"), copy_paths)
end

function _should_descend_for_copy(relpath::AbstractString, copy_paths)
    rel = replace(normpath(relpath), '\\' => '/')
    return any(copy_path -> rel == copy_path || startswith(rel, copy_path * "/") || startswith(copy_path, rel * "/"), copy_paths)
end
