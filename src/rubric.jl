struct RubricItem
    kind::Symbol
    visibility::Symbol
    points::Int
    description::String
    zero_marks::Bool
    spec::Any
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

function _parse_marks_line(stripped::AbstractString)
    m = match(r"^@marks\s+([+-]?\d+)\s+(\"(?:\\.|[^\"\\])*\")\s*$", stripped)
    m === nothing && return nothing
    points_text = m.captures[1]
    description_text = m.captures[2]
    points_text === nothing && return nothing
    description_text === nothing && return nothing
    points = tryparse(Int, points_text)
    points === nothing && return nothing
    points < 0 && return nothing
    parsed = Meta.parse(description_text; raise=false)
    parsed isa String || return nothing
    isempty(strip(parsed)) && return nothing
    occursin(r"[\r\n]", parsed) && return nothing
    return (points=points, description=parsed)
end

function _collect_rubric(reference_path::AbstractString)
    root = abspath(reference_path)
    items = RubricItem[]
    for (walkroot, dirs, files) in walkdir(root)
        filter!(d -> !(d in TEACHER_ONLY_DIRS), dirs)
        relroot = relpath(walkroot, root)
        for file in files
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
                        marks = _parse_marks_line(strip(line))
                        if marks !== nothing
                            push!(items, RubricItem(:marks, visibility, marks.points, marks.description, false, nothing, rel, i + offset))
                            continue
                        end
                        property = _parse_property_line(strip(line))
                        if property !== nothing
                            push!(items, RubricItem(property.kind, visibility, property.points, property.description, property.zero_marks, property.spec, rel, i + offset))
                            continue
                        end
                        reference = _parse_reference_test_line(strip(line))
                        reference === nothing && continue
                        push!(items, RubricItem(:reference_test, visibility, 0, reference.description, false, nothing, rel, i + offset))
                    end
                    i = j + 1
                else
                    i += 1
                end
            end
        end
    end
    return items
end

function _collect_reference_tests(reference_path::AbstractString)
    root = abspath(reference_path)
    specs = ReferenceTestSpec[]
    for (walkroot, dirs, files) in walkdir(root)
        filter!(d -> !(d in TEACHER_ONLY_DIRS), dirs)
        relroot = relpath(walkroot, root)
        for file in files
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
                        reference = _parse_reference_test_line(strip(line))
                        reference === nothing && continue
                        push!(specs, ReferenceTestSpec(visibility, reference.function_name, reference.input_expr, reference.description, rel, i + offset))
                    end
                    i = j + 1
                else
                    i += 1
                end
            end
        end
    end
    return specs
end

function _write_rubric(dst::AbstractString, items::Vector{RubricItem})
    public_marks = [item for item in items if item.kind == :marks && item.visibility == :public]
    hidden_marks = [item for item in items if item.kind == :marks && item.visibility == :hidden]
    public_properties = [item for item in items if item.kind != :marks && item.visibility == :public]
    hidden_properties = [item for item in items if item.kind != :marks && item.visibility == :hidden]
    total = sum(item.points for item in items if item.kind in (:marks, :require, :forbid))
    write(joinpath(dst, "RUBRIC.md"), """
# Rubric

This rubric is generated from `@marks` entries embedded beside the assignment
tests. Public criteria correspond to tests you can run in this skeleton. Hidden
criteria describe additional grading behaviour without revealing the private
test cases.

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
            println(io, "- ", item.points, " mark", item.points == 1 ? "" : "s", ": ", item.description)
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
            println(io, "- ", verb, points, ": ", item.description, suffix)
        end
    end
    return String(take!(io)) |> rstrip
end

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
            else
                return nothing
            end
        elseif arg isa String
            label = arg
        else
            return nothing
        end
    end
    description = label === nothing ? _property_description(kind, spec) : string(label, " (", _property_description(kind, spec), ")")
    return (kind=kind, spec=spec, points=points, zero_marks=zero_marks, description=description)
end

function _property_description(kind::Symbol, spec::Expr)
    property = string(spec.args[1])
    rendered_args = join(string.(spec.args[2:end]), ", ")
    prefix = kind == :require ? "must satisfy" : "must not satisfy"
    return "$prefix `$property($rendered_args)`"
end
