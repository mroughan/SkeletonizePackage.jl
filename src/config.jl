"""
    AssignmentConfig

Configuration for transforming a teacher reference package into a student
skeleton package.

Use [`read_assignment_config`](@ref) or pass a `SkeletonizePackage.inc` file to
[`generate_skeleton_package`](@ref) to construct this from INC metadata.
`instructions_path` is optional and points to Markdown that should be appended
to the generated student instructions. When it is `nothing`, generation uses a
root `student_notes.md` automatically when available. `ai_policy` controls the
generated `AGENTS.md` file and must be one of `:forbidden`, `:recorded`, or
`:allowed`.

# Example

```julia
julia> config = AssignmentConfig("Reference", "Skeleton", :student, true, true, nothing, :recorded);

julia> config.reference_path
"Reference"

julia> config.skeleton_path
"Skeleton"
```
"""
struct AssignmentConfig
    reference_path::String
    skeleton_path::String
    mode::Symbol
    force::Bool
    validate::Bool
    instructions_path::Union{Nothing, String}
    ai_policy::Symbol
end

const _AI_POLICIES = (:forbidden, :recorded, :allowed)
const _AI_POLICY_ERROR = "ai_policy must be forbidden, recorded, or allowed"

"""
    read_assignment_config(path="SkeletonizePackage.inc")

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
ai_policy = "recorded"
---
config
assignment
```

`instructions_path` may also be placed under `[student]`. If omitted, generation
automatically uses `student_notes.md` from the reference root when it exists.

# Example

Given a `SkeletonizePackage.inc` file with:

```text
---
[assignment]
reference_path = "."
skeleton_path = "../MyAssignmentSkeleton"
mode = "student"
force = true
validate = true
ai_policy = "forbidden"
---
config
assignment
```

reading it produces an `AssignmentConfig`:

```julia
julia> config = read_assignment_config("SkeletonizePackage.inc");

julia> basename(config.reference_path)
"MyAssignment"

julia> basename(config.skeleton_path)
"MyAssignmentSkeleton"

julia> config.force
true
```
"""
function read_assignment_config(path::AbstractString="SkeletonizePackage.inc")
    data = metadata(readinc(path))
    assignment = _metadata_section(data, "assignment")
    student_section = _metadata_section(data, "student")
    base = dirname(abspath(path))
    reference = get(assignment, "reference_path", "")
    skeleton = get(assignment, "skeleton_path", "")
    isempty(reference) && throw(ArgumentError("missing [assignment] reference_path in $path"))
    isempty(skeleton) && throw(ArgumentError("missing [assignment] skeleton_path in $path"))
    mode_str = lowercase(strip(String(get(assignment, "mode", "student"))))
    mode_str in ("student", "teacher") ||
        throw(ArgumentError("assignment.mode must be \"student\" or \"teacher\", got \"$mode_str\""))
    mode = Symbol(mode_str)
    force = _metadata_bool(get(assignment, "force", "false"), "assignment.force")
    validate = _metadata_bool(get(assignment, "validate", "true"), "assignment.validate")
    instructions = get(assignment, "instructions_path", get(student_section, "instructions_path", nothing))
    instructions_path = instructions === nothing ? nothing : _config_path(base, String(instructions))
    ai_policy = _metadata_ai_policy(get(assignment, "ai_policy", get(student_section, "ai_policy", "recorded")))
    return AssignmentConfig(_config_path(base, String(reference)), _config_path(base, String(skeleton)), mode, force, validate, instructions_path, ai_policy)
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

function _metadata_ai_policy(value)
    value isa Symbol && value in _AI_POLICIES && return value
    value isa AbstractString || throw(ArgumentError(_AI_POLICY_ERROR))
    policy = Symbol(lowercase(strip(value)))
    policy in _AI_POLICIES || throw(ArgumentError(_AI_POLICY_ERROR))
    return policy
end

function _config_path(base::AbstractString, path::AbstractString)
    return isabspath(path) ? String(path) : normpath(joinpath(base, path))
end
