struct RubricItem
    kind::Symbol
    visibility::Symbol
    points::Int
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

function _collect_rubric(source_path::AbstractString)
    root = abspath(source_path)
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
                            push!(items, RubricItem(:marks, visibility, marks.points, marks.description, rel, i + offset))
                            continue
                        end
                        property = _parse_property_line(strip(line))
                        if property !== nothing
                            push!(items, RubricItem(property.kind, visibility, 0, property.description, rel, i + offset))
                            continue
                        end
                        reference = _parse_reference_test_line(strip(line))
                        reference === nothing && continue
                        push!(items, RubricItem(:reference_test, visibility, 0, reference.description, rel, i + offset))
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

function _write_rubric(dst::AbstractString, items::Vector{RubricItem})
    public_marks = [item for item in items if item.kind == :marks && item.visibility == :public]
    hidden_marks = [item for item in items if item.kind == :marks && item.visibility == :hidden]
    public_properties = [item for item in items if item.kind != :marks && item.visibility == :public]
    hidden_properties = [item for item in items if item.kind != :marks && item.visibility == :hidden]
    total = sum(item.points for item in items if item.kind == :marks)
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
            println(io)
            println(io, "- ", verb, ": ", item.description)
        end
    end
    return String(take!(io)) |> rstrip
end

function _parse_reference_test_line(stripped::AbstractString)
    startswith(stripped, "@reference_test ") || return nothing
    text = strip(stripped[length("@reference_test ")+1:end])
    isempty(text) && return nothing
    return (description="reference behaviour `$text`",)
end

function _parse_property_line(stripped::AbstractString)
    m = match(r"^@(require|forbid)\s+(.+)$", stripped)
    m === nothing && return nothing
    kind_text = m.captures[1]
    spec_text = m.captures[2]
    kind_text === nothing && return nothing
    spec_text === nothing && return nothing
    parsed = Meta.parse(spec_text; raise=false)
    parsed isa Expr && parsed.head == :call || return nothing
    kind = kind_text == "require" ? :require : :forbid
    return (kind=kind, description=_property_description(kind, parsed))
end

function _property_description(kind::Symbol, spec::Expr)
    property = string(spec.args[1])
    rendered_args = join(string.(spec.args[2:end]), ", ")
    prefix = kind == :require ? "must satisfy" : "must not satisfy"
    return "$prefix `$property($rendered_args)`"
end
