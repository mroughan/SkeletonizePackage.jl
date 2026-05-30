struct SourceFunction
    name::Symbol
    args::Vector{String}
    body::String
    text::String
end

struct SourceProject
    root::String
    module_name::String
    files::Dict{String,String}
    text::String
    functions::Dict{Symbol,SourceFunction}
end

function _check_property(caller::Module, kind::Symbol, spec)
    ok = _property_holds(_source_project(caller), caller, spec)
    if kind == :require
        return ok
    elseif kind == :forbid
        return !ok
    else
        throw(ArgumentError("property kind must be :require or :forbid"))
    end
end

function _source_project(caller::Module)
    root = _source_project_root(caller)
    return _source_project_from_path(root)
end

function _source_project_from_path(root::AbstractString)
    module_name = _project_name(root)
    files = Dict{String,String}()
    src = joinpath(root, "src")
    if isdir(src)
        for (walkroot, _, names) in walkdir(src)
            for name in names
                endswith(name, ".jl") || continue
                path = joinpath(walkroot, name)
                files[relpath(path, root)] = read(path, String)
            end
        end
    end
    text = join(values(files), "\n")
    return SourceProject(root, module_name, files, text, _source_functions(text))
end

function _source_project_root(caller::Module)
    excluded = Set([:SkeletonPackages, :Test, :IncCSV])
    for name in names(caller; all=false, imported=true)
        name in excluded && continue
        isdefined(caller, name) || continue
        value = getfield(caller, name)
        value isa Module || continue
        path = pathof(value)
        path === nothing && continue
        root = dirname(dirname(path))
        isfile(joinpath(root, "Project.toml")) && return root
    end
    path = pathof(SkeletonPackages)
    path === nothing && throw(ArgumentError("could not locate package source"))
    return dirname(dirname(path))
end

function _source_functions(text::AbstractString)
    functions = Dict{Symbol,SourceFunction}()
    lines = split(String(text), '\n'; keepempty=true)
    i = 1
    while i <= length(lines)
        stripped = strip(lines[i])
        parsed = _function_header(stripped)
        if parsed !== nothing
            name, args = parsed
            body, j = _collect_source_block(lines, i)
            functions[name] = SourceFunction(name, args, join(body, "\n"), join(lines[i:j], "\n"))
            i += 1
        else
            i += 1
        end
    end
    return functions
end

function _function_header(line::AbstractString)
    m = match(r"^function\s+([A-Za-z_]\w*)\s*\(([^)]*)\)", line)
    if m !== nothing
        return (Symbol(m.captures[1]), _split_args(m.captures[2]))
    end
    m = match(r"^([A-Za-z_]\w*)\s*\(([^)]*)\)\s*=", line)
    m === nothing && return nothing
    return (Symbol(m.captures[1]), _split_args(m.captures[2]))
end

function _split_args(raw)
    raw === nothing && return String[]
    text = strip(raw)
    isempty(text) && return String[]
    return [strip(replace(split(arg, "="; limit=2)[1], r"::.*$" => "")) for arg in split(text, ",")]
end

function _collect_source_block(lines, start_i)
    header = strip(lines[start_i])
    if startswith(header, "function ")
        body = String[]
        depth = 1
        i = start_i + 1
        while i <= length(lines)
            s = strip(lines[i])
            if startswith(s, "function ") || occursin(r"\b(for|while|if|begin|let|try|quote|do)\b", s)
                depth += 1
            end
            if s == "end"
                depth -= 1
                depth == 0 && return body, i
            end
            push!(body, lines[i])
            i += 1
        end
        return body, length(lines)
    end
    return String[], start_i
end

function _property_holds(project::SourceProject, caller::Module, spec)
    spec isa Expr && spec.head == :call || throw(ArgumentError("properties must use call syntax, for example exported(:f)"))
    name = Symbol(spec.args[1])
    args = spec.args[2:end]
    if name == :exported
        return _is_exported(project, _symbol_arg(args, 1))
    elseif name == :exists
        return haskey(project.functions, _symbol_arg(args, 1))
    elseif name == :signature
        return _has_signature(project, _symbol_arg(args, 1), _int_arg(args, 2))
    elseif name == :docstring
        return _has_docstring(project, _symbol_arg(args, 1))
    elseif name == :imports
        return _has_import(project, _symbol_arg(args, 1))
    elseif name == :calls
        return length(args) == 1 ? _calls(project, nothing, _symbol_arg(args, 1)) : _calls(project, _symbol_arg(args, 1), _symbol_arg(args, 2))
    elseif name == :uses
        return _uses_operator(project, _symbol_arg(args, 1), _operator_arg(args, 2))
    elseif name == :recursive
        return _calls(project, _symbol_arg(args, 1), _symbol_arg(args, 1))
    elseif name == :loop
        return _has_loop(project, _symbol_arg(args, 1))
    elseif name == :globals
        return _has_global(project, _symbol_arg(args, 1))
    elseif name == :side_effects
        return _has_side_effects(project, _symbol_arg(args, 1))
    elseif name == :deterministic
        return _is_deterministic(caller, _symbol_arg(args, 1))
    elseif name == :comments
        return _comment_count(project) >= _kw_int(args, :min; default=1)
    elseif name == :lines_of_code
        return _lines_of_code(project) <= _kw_int(args, :max; default=typemax(Int))
    elseif name == :nested_loop_depth
        return _nested_loop_depth(project.text) <= _kw_int(args, :max; default=1)
    else
        throw(ArgumentError("unsupported property: $name"))
    end
end

function _symbol_arg(args, index)
    index <= length(args) || throw(ArgumentError("missing property argument $index"))
    arg = args[index]
    arg isa QuoteNode && arg.value isa Symbol && return arg.value
    arg isa Symbol && return arg
    arg isa String && return Symbol(arg)
    throw(ArgumentError("property argument $index must be a Symbol"))
end

function _int_arg(args, index)
    index <= length(args) || throw(ArgumentError("missing property argument $index"))
    arg = args[index]
    arg isa Integer && return Int(arg)
    throw(ArgumentError("property argument $index must be an integer"))
end

function _operator_arg(args, index)
    index <= length(args) || throw(ArgumentError("missing property argument $index"))
    arg = args[index]
    arg isa QuoteNode && return string(arg.value)
    arg isa Symbol && return string(arg)
    arg isa String && return arg
    throw(ArgumentError("operator argument must be a Symbol or String"))
end

function _kw_int(args, key::Symbol; default::Int)
    for arg in args
        if arg isa Expr && arg.head in (:(=), :kw) && arg.args[1] == key
            value = arg.args[2]
            value isa Integer || throw(ArgumentError("$key must be an integer"))
            return Int(value)
        end
    end
    return default
end

function _is_exported(project::SourceProject, name::Symbol)
    exports = String[]
    collecting = false
    for line in split(project.text, '\n')
        stripped = strip(line)
        if startswith(stripped, "export ")
            push!(exports, stripped[length("export ")+1:end])
            collecting = endswith(stripped, ",")
        elseif collecting
            push!(exports, stripped)
            collecting = endswith(stripped, ",")
        end
    end
    for part in split(join(exports, " "), ",")
        strip(part) == string(name) && return true
    end
    return false
end

function _has_signature(project::SourceProject, name::Symbol, arity::Int)
    f = get(project.functions, name, nothing)
    f === nothing && return false
    return length(f.args) == arity
end

function _has_docstring(project::SourceProject, name::Symbol)
    pattern = Regex("\"\"\"[\\s\\S]*?\"\"\"\\s*(?:function\\s+$(name)\\s*\\(|$(name)\\s*\\()")
    return occursin(pattern, project.text)
end

function _has_import(project::SourceProject, name::Symbol)
    pattern = Regex("\\b(using|import)\\s+([^\\n]*\\b$(name)\\b)")
    return occursin(pattern, project.text)
end

function _calls(project::SourceProject, function_name::Union{Nothing, Symbol}, callee::Symbol)
    text = function_name === nothing ? project.text : get(project.functions, function_name, SourceFunction(function_name, String[], "", "")).body
    return occursin(Regex("\\b$(callee)\\s*\\("), text)
end

function _uses_operator(project::SourceProject, function_name::Symbol, operator::AbstractString)
    f = get(project.functions, function_name, nothing)
    f === nothing && return false
    return occursin(operator, f.body)
end

function _has_loop(project::SourceProject, function_name::Symbol)
    f = get(project.functions, function_name, nothing)
    f === nothing && return false
    return occursin(r"\b(for|while)\b", f.body)
end

function _has_global(project::SourceProject, function_name::Symbol)
    f = get(project.functions, function_name, nothing)
    f === nothing && return false
    return occursin(r"\bglobal\b", f.body)
end

function _has_side_effects(project::SourceProject, function_name::Symbol)
    f = get(project.functions, function_name, nothing)
    f === nothing && return false
    return occursin(r"\b(push!|append!|setindex!|delete!|empty!|sort!|splice!|pop!|println|print)\s*\(", f.body) ||
           occursin(r"\[[^\]]+\]\s*=", f.body)
end

function _is_deterministic(caller::Module, function_name::Symbol)
    isdefined(caller, function_name) || return false
    f = getfield(caller, function_name)
    samples = (-2, -1, 0, 1, 2, 5)
    for sample in samples
        first = try
            f(sample)
        catch
            continue
        end
        second = try
            f(sample)
        catch
            return false
        end
        first == second || return false
    end
    return true
end

function _comment_count(project::SourceProject)
    return count(line -> startswith(strip(line), "#"), split(project.text, '\n'))
end

function _lines_of_code(project::SourceProject)
    return count(line -> begin
        stripped = strip(line)
        !isempty(stripped) && !startswith(stripped, "#")
    end, split(project.text, '\n'))
end

function _nested_loop_depth(text::AbstractString)
    depth = 0
    maxdepth = 0
    stack = Symbol[]
    for line in split(text, '\n')
        stripped = strip(line)
        if occursin(r"^(for|while)\b", stripped)
            depth += 1
            maxdepth = max(maxdepth, depth)
            push!(stack, :loop)
        elseif occursin(r"^(if|function|begin|let|try)\b", stripped)
            push!(stack, :other)
        elseif stripped == "end" && !isempty(stack)
            top = pop!(stack)
            top == :loop && (depth -= 1)
        end
    end
    return maxdepth
end
