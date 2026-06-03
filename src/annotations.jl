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

Mark teacher-only grading tests. These tests are removed from skeleton packages
but run normally in the annotated reference package.

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

Assert that a source-code property holds for the package under test. Intended
for use inside `@student_test` or `@hidden_test` blocks.

# Example

```julia
@assignment_requirements begin
    @require exported(mysort) marks=1 id="interface-export" "exports the required function"
    @require signature(mysort, 1)
end
```

If both checks pass, the surrounding testset passes. In the generated rubric the
requirements are summarized as:

```text
- Requires (1 mark): exports the required function (must satisfy `exported(mysort)`)
- Requires: must satisfy `signature(mysort, 1)`
```

During grading, `marks=N` awards marks for the property itself. `zero_marks=true`
turns a failed property into a whole-assignment zeroing condition.
"""
macro require(spec, args...)
    return esc(:(@test SkeletonizePackage._check_property($__module__, :require, $(QuoteNode(spec)))))
end

"""
    @forbid property(...) [marks=N] [zero_marks=true] [id="stable-id"] ["description"]

Assert that a source-code property does not hold for the package under test.
Intended for use inside `@student_test` or `@hidden_test` blocks.

# Example

```julia
@assignment_requirements begin
    @forbid calls(mysort, sort)
    @forbid imports(DataFrames) zero_marks=true "does not use a shortcut package"
end
```

If either forbidden property is present, the generated test fails.
During grading, the `zero_marks=true` example gives zero for the whole assignment if
the submitted source imports `DataFrames`.
"""
macro forbid(spec, args...)
    return esc(:(@test SkeletonizePackage._check_property($__module__, :forbid, $(QuoteNode(spec)))))
end

"""
    @assignment_requirements begin
        ...
    end

Group source-code requirements and reference-test metadata in a test file.

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
    return esc(block)
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

"""
    strip_reference_annotations(text::AbstractString; mode=:student)

Transform annotated Julia source text.

For `mode = :student`, remove `@solution` and `@hidden_test` regions, and keep
the bodies of `@scaffolding` and `@student_test` regions. For `mode = :teacher`,
keep `@solution`, `@student_test`, and `@hidden_test` bodies, and remove
`@scaffolding` regions.

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
function strip_reference_annotations(text::AbstractString; mode::Symbol=:student)
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
                append!(out, block)
            end
            i = j + 1
        else
            push!(out, line)
            i += 1
        end
    end
    return join(out, "\n")
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
