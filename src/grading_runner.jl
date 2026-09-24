# Executed in a child Julia process; only standard libraries are required here.
module GradingRunner
if length(ARGS) >= 3
    empty!(LOAD_PATH)
    append!(LOAD_PATH, ["@", ARGS[3], "@stdlib"])
end
using Test
using TOML

const OUTPUT = ARGS[2]
const SETS = Test.AbstractTestSet[]

mutable struct RecordedTestSet <: Test.AbstractTestSet
    description::String
    parent::Int
    counts::Vector{Int}
    details::Vector{String}
    marks::Vector{String}
    references::Vector{String}
    aborted::Bool
    completed::Bool
end

function RecordedTestSet(description; kwargs...)
    parent = Test.get_testset_depth() == 0 ? nothing : Test.get_testset()
    index = findfirst(x -> x === parent, SETS)
    ts = RecordedTestSet(string(description), something(index, 0), zeros(Int, 4), String[], String[], String[], false, false)
    push!(SETS, ts)
    checkpoint()
    return ts
end

function descendants(index)
    indices = [index]
    for i in (index + 1):length(SETS)
        SETS[i].parent in indices && push!(indices, i)
    end
    return indices
end

function rows()
    return map(eachindex(SETS)) do i
        ts = SETS[i]
        indices = descendants(i)
        counts = reduce(+, (SETS[j].counts for j in indices))
        status = !ts.completed ? "incomplete" : counts[3] > 0 ? "error" :
                 counts[2] > 0 ? "failed" : sum(counts[1:3]) == 0 ? "not_run" : "passed"
        Dict("name" => ts.description, "status" => status,
             "passed" => counts[1], "failed" => counts[2],
             "errored" => counts[3], "broken" => counts[4],
             "details" => reduce(vcat, (SETS[j].details for j in indices)),
             "marks" => ts.marks,
             "references" => unique(reduce(vcat, (SETS[j].references for j in indices))),
             "aborted" => any(j -> SETS[j].aborted || !SETS[j].completed, indices))
    end
end

function checkpoint()
    # Atomic replacement preserves the previous snapshot on timeout or exit().
    open(OUTPUT * ".next", "w") do io
        TOML.print(io, Dict("tests" => rows()))
    end
    mv(OUTPUT * ".next", OUTPUT; force=true)
end

function Test.record(ts::RecordedTestSet, result::Test.Result)
    index = result isa Test.Pass ? 1 : result isa Test.Fail ? 2 : result isa Test.Error ? 3 : 4
    ts.counts[index] += 1
    result isa Test.Error && result.test_type == :nontest_error && (ts.aborted = true)
    if index in (2, 3)
        detail = sprint(show, result)
        push!(ts.details, detail)
        println(stderr, detail)
    end
    checkpoint()
    return result
end

Test.record(::RecordedTestSet, ::RecordedTestSet) = nothing

# Explicit foreign testset types are not silently treated as successful.
function Test.record(ts::RecordedTestSet, child::Test.AbstractTestSet)
    ts.counts[3] += 1
    ts.aborted = true
    detail = "Unsupported explicit testset type: $(typeof(child)); use ordinary @testset blocks."
    push!(ts.details, detail)
    println(stderr, detail)
    checkpoint()
end

function Test.finish(ts::RecordedTestSet)
    ts.completed = true
    Test.get_testset_depth() > 0 && Test.record(Test.get_testset(), ts)
    checkpoint()
    return ts
end

function mark!(path, line, reference=false)
    ts = Test.get_testset()
    ts isa RecordedTestSet || return
    push!(reference ? ts.references : ts.marks, string(abspath(path), ":", line))
    checkpoint()
end

function description(ex, fallback)
    ex isa Expr || return fallback
    if ex.head == :macrocall && ex.args[1] == Symbol("@marks")
        label = findfirst(x -> x isa String, ex.args[4:end])
        label === nothing || return ex.args[label + 3]
    end
    for arg in ex.args
        label = description(arg, fallback)
        label == fallback || return label
    end
    return fallback
end

function instrument(ex, path)
    ex isa Expr || return ex
    ex.head in (:quote, :inert) && return ex
    if ex.head == :macrocall
        name = ex.args[1]
        if name in (Symbol("@student_test"), Symbol("@hidden_test"))
            label = description(ex, string(name))
            body = instrument(ex.args[end], path)
            return Expr(:macrocall, GlobalRef(Test, Symbol("@testset")), ex.args[2],
                        label, body)
        elseif name == Symbol("@marks")
            return Expr(:call, GlobalRef(GradingRunner, :mark!), path, ex.args[2].line)
        elseif name == Symbol("@reference_test")
            return Expr(:call, GlobalRef(GradingRunner, :mark!), path, ex.args[2].line, true)
        end
    end
    return Expr(ex.head, (instrument(arg, path) for arg in ex.args)...)
end

baremodule Tests
using Base
using ..GradingRunner: instrument
function include(path::AbstractString)
    source = Base.source_path()
    resolved = isabspath(path) ? path : joinpath(source === nothing ? pwd() : dirname(source), path)
    return Base.include(ex -> instrument(ex, abspath(resolved)), Tests, resolved)
end
end

function main()
    Test.@testset RecordedTestSet "All behavioral tests" begin
        Tests.include(abspath(ARGS[1]))
    end
    root = first(rows())
    println("Behavioral tests: ", root["passed"], " passed, ", root["failed"],
            " failed, ", root["errored"], " errors, ", root["broken"], " broken/skipped")
    exit(root["status"] in ("passed", "not_run") ? 0 : 1)
end
end

GradingRunner.main()
