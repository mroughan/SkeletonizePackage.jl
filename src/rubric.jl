struct RubricItem
    id::String
    kind::Symbol
    visibility::Symbol
    points::Int
    description::String
    zero_marks::Bool
    spec::Union{Nothing, Expr}
    path::String
    line::Int
end

struct ReferenceTestSpec
    visibility::Symbol
    function_name::Symbol
    input_expr::String
    description::String
    path::String
    line::Int
end

const _PROPERTY_CRITERION_KINDS = (:require, :forbid)
const _SCORED_CRITERION_KINDS = (:marks, _PROPERTY_CRITERION_KINDS...)

_is_property_criterion(kind::Symbol) = kind in _PROPERTY_CRITERION_KINDS
_is_scored_criterion(kind::Symbol) = kind in _SCORED_CRITERION_KINDS

"""
    _parse_marks_line(stripped)

Parse a single stripped source line as an `@marks` call.
Returns a named tuple `(points, description, id)` on success, `nothing` on failure.
"""
function _parse_marks_line(stripped::AbstractString)
    parsed = Meta.parse(stripped; raise=false)
    parsed isa Expr && parsed.head == :macrocall || return nothing
    length(parsed.args) >= 4 || return nothing
    parsed.args[1] == Symbol("@marks") || return nothing
    points = parsed.args[3]
    points isa Integer || return nothing
    points < 0 && return nothing
    description = nothing
    id = nothing
    for arg in parsed.args[4:end]
        if arg isa String
            description === nothing || return nothing
            description = arg
        elseif arg isa Expr && arg.head == :(=)
            key = arg.args[1]
            value = arg.args[2]
            if key == :id
                value isa String || return nothing
                id = value
            else
                return nothing
            end
        else
            return nothing
        end
    end
    description isa String || return nothing
    isempty(strip(description)) && return nothing
    occursin(r"[\r\n]", description) && return nothing
    _valid_rubric_id(id) || return nothing
    return (points=Int(points), description=description, id=id)
end

"""
    _collect_rubric_and_specs(reference_path)

Walk `reference_path` once and collect all `RubricItem`s and `ReferenceTestSpec`s in a
single pass. Returns `(items, specs)`. Called by `_collect_rubric` and directly by
`grade_submission` to avoid a second identical walkdir.
"""
function _collect_rubric_and_specs(reference_path::AbstractString)
    root = abspath(reference_path)
    items = RubricItem[]
    specs = ReferenceTestSpec[]
    for (walkroot, dirs, files) in walkdir(root)
        filter!(d -> !(d in TEACHER_ONLY_DIRS), dirs)
        relroot = relpath(walkroot, root)
        for file in files
            _is_teacher_only_file(file) && continue
            any(ext -> endswith(file, ext), TRANSFORMED_EXTENSIONS) || continue
            path = joinpath(walkroot, file)
            rel = relroot == "." ? file : joinpath(relroot, file)
            lines = split(read(path, String), '\n'; keepempty=true)
            i = 1
            while i <= length(lines)
                stripped = strip(lines[i])
                if stripped in ("@student_test begin", "@hidden_test begin", "@assignment_requirements begin")
                    visibility = startswith(stripped, "@hidden_test") ? :hidden : :public
                    block, j = _collect_block(lines, i)
                    for (offset, line) in enumerate(block)
                        sline = strip(line)
                        marks = _parse_marks_line(sline)
                        if marks !== nothing
                            push!(items, RubricItem(_rubric_id(marks.id, :marks, visibility, marks.description, length(items) + 1), :marks, visibility, marks.points, marks.description, false, nothing, rel, i + offset))
                            continue
                        end
                        property = _parse_property_line(sline)
                        if property !== nothing
                            push!(items, RubricItem(_rubric_id(property.id, property.kind, visibility, property.description, length(items) + 1), property.kind, visibility, property.points, property.description, property.zero_marks, property.spec, rel, i + offset))
                            continue
                        end
                        reference = _parse_reference_test_line(sline)
                        if reference !== nothing
                            push!(items, RubricItem(_rubric_id(nothing, :reference_test, visibility, reference.description, length(items) + 1), :reference_test, visibility, 0, reference.description, false, nothing, rel, i + offset))
                            push!(specs, ReferenceTestSpec(visibility, reference.function_name, reference.input_expr, reference.description, rel, i + offset))
                        end
                    end
                    i = j + 1
                else
                    i += 1
                end
            end
        end
    end
    return items, specs
end

"""
    _collect_rubric(reference_path)

Walk `reference_path` and return all `RubricItem`s. Thin wrapper around
`_collect_rubric_and_specs` for callers that do not need the `ReferenceTestSpec`s.
"""
function _collect_rubric(reference_path::AbstractString)
    items, _ = _collect_rubric_and_specs(reference_path)
    return items
end

function _write_rubric(dst::AbstractString, items::Vector{RubricItem})
    public_marks = [item for item in items if item.kind == :marks && item.visibility == :public]
    hidden_marks = [item for item in items if item.kind == :marks && item.visibility == :hidden]
    public_properties = [item for item in items if item.kind != :marks && item.visibility == :public]
    hidden_properties = [item for item in items if item.kind != :marks && item.visibility == :hidden]
    total = sum(item.points for item in items if _is_scored_criterion(item.kind))
    write(joinpath(dst, "RUBRIC.md"), """
# Rubric

This rubric is generated from `@marks` entries embedded beside the assignment
tests. Public criteria correspond to tests you can run in this skeleton. Hidden
criteria describe additional grading behaviour without revealing the private
test cases. Each `@marks` line creates a separate criterion. Test blocks are
shown as named testsets using their first marks description; teachers are
encouraged to keep one coherent marked criterion per block.

Total: $total marks

$(_rubric_marks_section("Public Criteria", public_marks))

$(_rubric_marks_section("Hidden Criteria", hidden_marks))

$(_rubric_property_section("Public Code Properties", public_properties))

$(_rubric_property_section("Hidden Code Properties", hidden_properties))
""")
end

function _rubric_marks_section(title::AbstractString, items::Vector{RubricItem})
    io = IOBuffer()
    println(io, "## ", title)
    if isempty(items)
        println(io)
        println(io, "No marked criteria were provided for this section.")
    else
        for item in items
            println(io)
            println(io, "- `", item.id, "`: ", item.points, " mark", item.points == 1 ? "" : "s", ": ", item.description)
        end
    end
    return String(take!(io)) |> rstrip
end

function _rubric_property_section(title::AbstractString, items::Vector{RubricItem})
    io = IOBuffer()
    println(io, "## ", title)
    if isempty(items)
        println(io)
        println(io, "No code-property criteria were provided for this section.")
    else
        for item in items
            verb = item.kind == :require ? "Requires" : item.kind == :forbid ? "Forbids" : "Reference test"
            suffix = item.zero_marks ? " Zero marks if failed." : ""
            points = item.points > 0 ? " ($(item.points) mark$(item.points == 1 ? "" : "s"))" : ""
            println(io)
            println(io, "- `", item.id, "`: ", verb, points, ": ", item.description, suffix)
        end
    end
    return String(take!(io)) |> rstrip
end

"""
    _parse_reference_test_line(stripped)

Parse a stripped source line as a `@reference_test` declaration.
Returns a named tuple `(function_name, input_expr, description)` on success, `nothing` on failure.
"""
function _parse_reference_test_line(stripped::AbstractString)
    startswith(stripped, "@reference_test ") || return nothing
    text = strip(stripped[length("@reference_test ")+1:end])
    isempty(text) && return nothing
    m = match(r"^([A-Za-z_]\w*)\s+(?:generator|inputs)\s*=\s*(.+)$", text)
    m === nothing && return nothing
    function_text = m.captures[1]
    input_text = m.captures[2]
    function_text === nothing && return nothing
    input_text === nothing && return nothing
    parsed_inputs = Meta.parse(input_text; raise=false)
    parsed_inputs isa Expr && parsed_inputs.head == :error && return nothing
    return (
        function_name=Symbol(function_text),
        input_expr=strip(input_text),
        description="reference behaviour `$text`",
    )
end

"""
    _parse_property_line(stripped)

Parse a stripped source line as a `@require` or `@forbid` declaration.
Returns a named tuple `(kind, spec, points, zero_marks, description, id)` on success, `nothing` on failure.
"""
function _parse_property_line(stripped::AbstractString)
    parsed = Meta.parse(stripped; raise=false)
    parsed isa Expr && parsed.head == :macrocall || return nothing
    length(parsed.args) >= 3 || return nothing
    macro_name = parsed.args[1]
    macro_name in (Symbol("@require"), Symbol("@forbid")) || return nothing
    spec = parsed.args[3]
    spec isa Expr && spec.head == :call || return nothing
    kind = macro_name == Symbol("@require") ? :require : :forbid
    points = 0
    zero_marks = false
    label = nothing
    id = nothing
    for arg in parsed.args[4:end]
        if arg isa Expr && arg.head == :(=)
            key = arg.args[1]
            value = arg.args[2]
            if key == :marks
                value isa Integer || return nothing
                value < 0 && return nothing
                points = Int(value)
            elseif key == :zero_marks
                value isa Bool || return nothing
                zero_marks = value
            elseif key == :id
                value isa String || return nothing
                id = value
            else
                return nothing
            end
        elseif arg isa String
            label = arg
        else
            return nothing
        end
    end
    _valid_rubric_id(id) || return nothing
    description = label === nothing ? _property_description(kind, spec) : string(label, " (", _property_description(kind, spec), ")")
    return (kind=kind, spec=spec, points=points, zero_marks=zero_marks, description=description, id=id)
end

function _property_description(kind::Symbol, spec::Expr)
    property = string(spec.args[1])
    rendered_args = join(string.(spec.args[2:end]), ", ")
    prefix = kind == :require ? "must satisfy" : "must not satisfy"
    return "$prefix `$property($rendered_args)`"
end

function _valid_rubric_id(id)
    id === nothing && return true
    id isa AbstractString || return false
    return occursin(r"^[A-Za-z][A-Za-z0-9_.:-]*$", id)
end

function _rubric_id(id, kind::Symbol, visibility::Symbol, description::AbstractString, index::Int)
    id !== nothing && return String(id)
    stem = lowercase(replace(description, r"[^A-Za-z0-9]+" => "-"))
    stem = strip(stem, '-')
    isempty(stem) && (stem = string(kind))
    length(stem) > 36 && (stem = stem[1:36])
    return string(visibility, "-", kind, "-", lpad(index, 2, '0'), "-", stem)
end
