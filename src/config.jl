"""
    AssignmentConfig

Configuration for transforming a teacher reference package into a student
skeleton package.

Use [`read_assignment_config`](@ref) or pass a `SkeletonPackages.inc` file to
[`generate_student_package`](@ref) to construct this from INC metadata.
`instructions_path` is optional and points to Markdown that should be appended
to the generated student instructions.
"""
struct AssignmentConfig
    source_path::String
    student_path::String
    mode::Symbol
    force::Bool
    validate::Bool
    instructions_path::Union{Nothing, String}
end

"""
    read_assignment_config(path="SkeletonPackages.inc")

Read an assignment configuration file.

Expected INC metadata shape:

```text
---
[assignment]
reference_path = "examples/SortingAssignment"
skeleton_path = "SortingAssignmentStudent"
mode = "student"
force = false
validate = true
instructions_path = "student_notes.md"
---
config
assignment
```

`instructions_path` may also be placed under `[student]`.
"""
function read_assignment_config(path::AbstractString="SkeletonPackages.inc")
    data = metadata(readinc(path))
    assignment = _metadata_section(data, "assignment")
    student_section = _metadata_section(data, "student")
    base = dirname(abspath(path))
    source = get(assignment, "reference_path", get(assignment, "source_path", get(assignment, "source", "")))
    student = get(assignment, "skeleton_path", get(assignment, "student_path", get(assignment, "student_package", "")))
    isempty(source) && throw(ArgumentError("missing [assignment] reference_path in $path"))
    isempty(student) && throw(ArgumentError("missing [assignment] skeleton_path in $path"))
    mode = Symbol(String(get(assignment, "mode", "student")))
    force = _metadata_bool(get(assignment, "force", "false"), "assignment.force")
    validate = _metadata_bool(get(assignment, "validate", "true"), "assignment.validate")
    instructions = get(assignment, "instructions_path", get(student_section, "instructions_path", nothing))
    instructions_path = instructions === nothing ? nothing : _config_path(base, String(instructions))
    return AssignmentConfig(_config_path(base, String(source)), _config_path(base, String(student)), mode, force, validate, instructions_path)
end

function _metadata_section(data::AbstractDict, name::AbstractString)
    section = get(data, name, Dict{String, Any}())
    section isa AbstractDict || throw(ArgumentError("[$name] must be an INC metadata section"))
    return section
end

function _metadata_bool(value, name::AbstractString)
    value isa Int && value in (0, 1) && return value == 1
    value isa String || throw(ArgumentError("$name must be true or false"))
    normalized = lowercase(strip(value))
    normalized in ("true", "yes", "1") && return true
    normalized in ("false", "no", "0") && return false
    throw(ArgumentError("$name must be true or false"))
end

function _config_path(base::AbstractString, path::AbstractString)
    return isabspath(path) ? String(path) : normpath(joinpath(base, path))
end
