"""
    @solution begin
        ...
    end

Mark a teacher-only implementation block.

`generate_skeleton_package` removes this block from skeleton packages. At runtime
inside the reference package, the macro expands to its body so the reference
implementation remains executable.

# Example

```julia
julia> @solution begin
           2 + 3
       end
5
```
"""
macro solution(block)
    return esc(block)
end

"""
    @scaffolding begin
        ...
    end

Mark the scaffolding code that students should receive in place of a teacher
solution.

`generate_skeleton_package` keeps this block for skeleton packages and removes it
from teacher-mode output. In the reference package, the macro expands to `nothing`
so scaffolding code does not run.

# Example

```julia
julia> @scaffolding begin
           error("TODO")
       end
```

The expression returns `nothing`, so no value is printed at the REPL.
"""
macro scaffolding(block)
    return :(nothing)
end

"""
    @student_test begin
        ...
    end

Mark tests that should be visible to students and also run for teachers.
Generated Julia output wraps each kept block in a named `@testset`, using the
first `@marks` description when present.

# Example

```julia
julia> @student_test begin
           3 + 4
       end
7
```
"""
macro student_test(block)
    return esc(block)
end

"""
    @hidden_test begin
        ...
    end

Mark teacher-only grading tests. These tests are removed from student skeletons
but run normally in the annotated reference package and teacher-mode output.
Teacher-mode Julia output wraps each block in a named `@testset`.

# Example

```julia
julia> @hidden_test begin
           5 + 6
       end
11
```
"""
macro hidden_test(block)
    return esc(block)
end

"""
    @marks points "description" [id="stable-id"]

Attach rubric metadata to nearby tests. The macro is a runtime no-op so teacher
and generated student tests can execute normally, while `generate_skeleton_package`
extracts these lines into `RUBRIC.md`.

Each `@marks` line creates a rubric criterion. The first description in a
student or hidden test block also names its generated `@testset`. Prefer one
coherent marked criterion per block.

# Example

```julia
@student_test begin
    @marks 1 "sorts a two-element vector" id="sort-basic"
    @test mysort([2, 1]) == [1, 2]
end
```

Generated rubric entry:

```text
- `sort-basic`: 1 mark: sorts a two-element vector
```
"""
macro marks(args...)
    return :(nothing)
end

"""
    @require property(...) [marks=N] [zero_marks=true] [id="stable-id"] ["description"]

Record a source-code property that must hold for a student submission. The macro
is a runtime no-op so the teacher reference may deliberately omit the property;
grading evaluates it separately.

# Example

```julia
@assignment_requirements begin
    @require exported(mysort) marks=1 id="interface-export" "exports the required function"
    @require signature(mysort, 1)
end
```

Requirements are grading metadata and do not run as ordinary reference-package
tests. During grading they are evaluated against the student submission. In the
generated rubric they are summarized as:

```text
- Requires (1 mark): exports the required function (must satisfy `exported(mysort)`)
- Requires: must satisfy `signature(mysort, 1)`
```

During grading, `marks=N` awards marks for the property itself. `zero_marks=true`
turns a failed property into a whole-assignment zeroing condition.
"""
macro require(spec, args...)
    return :(nothing)
end

"""
    @forbid property(...) [marks=N] [zero_marks=true] [id="stable-id"] ["description"]

Record a source-code property that must not hold for a student submission. The
macro is a runtime no-op; grading evaluates it separately.

# Example

```julia
@assignment_requirements begin
    @forbid calls(mysort, sort)
    @forbid imports(DataFrames) zero_marks=true "does not use a shortcut package"
end
```

During grading, the `zero_marks=true` example gives zero for the whole assignment
if the submitted source imports `DataFrames`.
"""
macro forbid(spec, args...)
    return :(nothing)
end

"""
    @assignment_requirements begin
        ...
    end

Group source-code requirements and reference-test metadata in a test file.
The block is a runtime no-op so a reference solution may deliberately omit
student-facing properties such as exports or docstrings. Grading evaluates the
recorded requirements against submissions separately.

# Example

```julia
@assignment_requirements begin
    @require exported(fib)
    @forbid calls(fib, factorial)
    @reference_test fib generator=1:10
end
```

Generated rubric excerpt:

```text
- Requires: must satisfy `exported(fib)`
- Forbids: must not satisfy `calls(fib, factorial)`
- Reference test: reference behaviour `fib generator=1:10`
```
"""
macro assignment_requirements(block)
    return :(nothing)
end

"""
    @reference_test f generator=1:30

Record reference-test metadata for the generated rubric and grading harness. At
runtime in ordinary tests this macro is a no-op. During grading,
[`grade_submission`](@ref) evaluates the named function on the generated inputs
in both the reference package and the submission package, then compares their
outputs.

# Example

```julia
@reference_test fib generator=1:30
```

Generated rubric entry:

```text
- Reference test: reference behaviour `fib generator=1:30`
```

During grading, each value produced by `generator` is passed to `fib`. Tuple
inputs are splatted, so `generator=[(1, 2), (3, 4)]` tests a two-argument
function.
"""
macro reference_test(args...)
    return :(nothing)
end

const ANNOTATION_OPENERS = Set(["@solution", "@scaffolding", "@student_test", "@hidden_test"])
const ANNOTATION_BLOCK_OPENERS = Set(["$name begin" for name in ANNOTATION_OPENERS])
const TEACHER_ONLY_DIRS = Set([".git", "build", "solutions", ".julia", ".CondaPkg"])
const TEACHER_ONLY_FILES = Set(["GRADING_PLAN.md", "TEACHER_CHECKLIST.md", "student_notes.md"])
const TRANSFORMED_EXTENSIONS = (".jl", ".md", ".toml", ".inc")
const _RE_ANNOTATION_BLOCK_OPENER = r"^\s*(for|while|if|function|let|try|quote)\b|\bbegin\b|\bdo\s*$"

_is_teacher_only_file(file::AbstractString) =
    file in TEACHER_ONLY_FILES || endswith(file, "~") ||
    (startswith(file, "#") && endswith(file, "#"))

"""
    strip_reference_annotations(text::AbstractString; mode=:student, testsets=false)

Transform annotated Julia source text.

For `mode = :student`, remove `@solution` and `@hidden_test` regions, and keep
the bodies of `@scaffolding` and `@student_test` regions. For `mode = :teacher`,
keep `@solution`, `@student_test`, and `@hidden_test` bodies, and remove
`@scaffolding` regions.

With `testsets=true`, kept student and hidden test blocks are wrapped in named
`@testset`s. Generation enables this for transformed Julia files.

This implementation is intentionally line-oriented. Annotation macros must
appear on their own line as `@solution begin`, `@scaffolding begin`,
`@student_test begin`, or `@hidden_test begin`.

# Example

```julia
julia> text = \"\"\"
       function f()
           @solution begin
               return 42
           end
           @scaffolding begin
               error("TODO")
           end
       end
       \"\"\";

julia> println(strip_reference_annotations(text; mode=:student))
function f()
    error("TODO")
end

julia> println(strip_reference_annotations(text; mode=:teacher))
function f()
    return 42
end
```
"""
function strip_reference_annotations(text::AbstractString; mode::Symbol=:student, testsets::Bool=false)
    lines = split(String(text), '\n'; keepempty=true)
    out = String[]
    i = 1
    while i <= length(lines)
        line = lines[i]
        stripped = strip(line)
        if stripped in ANNOTATION_BLOCK_OPENERS
            macro_name = split(stripped)[1]
            block, j = _collect_block(lines, i)
            if _keep_body(macro_name, mode)
                if testsets && macro_name in ("@student_test", "@hidden_test")
                    append!(out, _testset_block(line, macro_name, block))
                else
                    append!(out, block)
                end
            end
            i = j + 1
        else
            push!(out, line)
            i += 1
        end
    end
    return join(out, "\n")
end

function _testset_block(opener::AbstractString, macro_name::AbstractString, block)
    indent = first(opener, findfirst(!=(' '), opener) === nothing ? 0 : findfirst(!=(' '), opener) - 1)
    default = macro_name == "@student_test" ? "Student tests" : "Hidden tests"
    label = default
    for line in block
        marks = _parse_marks_line(strip(line))
        marks === nothing || (label = marks.description; break)
    end
    return vcat(["$(indent)@testset $(repr(label)) begin"], block, ["$(indent)end"])
end

function _keep_body(macro_name::AbstractString, mode::Symbol)
    if mode == :student
        return macro_name in ("@scaffolding", "@student_test")
    elseif mode == :teacher
        return macro_name in ("@solution", "@student_test", "@hidden_test")
    else
        throw(ArgumentError("mode must be :student or :teacher"))
    end
end

function _collect_block(lines, start_i)
    body = String[]
    depth = 1
    i = start_i + 1
    while i <= length(lines)
        s = strip(lines[i])
        occursin(_RE_ANNOTATION_BLOCK_OPENER, s) && (depth += 1)
        if s == "end"
            depth -= 1
            if depth == 0
                return body, i
            end
        end
        push!(body, lines[i])
        i += 1
    end
    throw(ArgumentError("unterminated annotated block beginning at line $start_i"))
end
