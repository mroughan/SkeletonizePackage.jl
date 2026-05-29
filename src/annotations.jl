"""
    @solution begin
        ...
    end

Mark a teacher-only implementation block.

`generate_student_package` removes this block from student packages. At runtime
inside the teacher package, the macro expands to its body so the reference
implementation remains executable.
"""
macro solution(block)
    return esc(block)
end

"""
    @starter begin
        ...
    end

Mark the starter code that students should receive in place of a teacher
solution.

`generate_student_package` keeps this block for student packages and removes it
from teacher-mode output. In the teacher package, the macro expands to `nothing`
so starter code does not run.
"""
macro starter(block)
    return :(nothing)
end

"""
    @student_test begin
        ...
    end

Mark tests that should be visible to students and also run for teachers.
"""
macro student_test(block)
    return esc(block)
end

"""
    @hidden_test begin
        ...
    end

Mark teacher-only grading tests. These tests are removed from student packages
but run normally in the annotated teacher package.
"""
macro hidden_test(block)
    return esc(block)
end

"""
    @marks points "description"

Attach rubric metadata to nearby tests. The macro is a runtime no-op so teacher
and generated student tests can execute normally, while `generate_student_package`
extracts these lines into `RUBRIC.md`.
"""
macro marks(args...)
    return :(nothing)
end

"""
    @require property(...)

Assert that a source-code property holds for the package under test. Intended
for use inside `@student_test` or `@hidden_test` blocks.
"""
macro require(spec)
    return esc(:(@test SkeletonPackages._check_property($__module__, :require, $(QuoteNode(spec)))))
end

"""
    @forbid property(...)

Assert that a source-code property does not hold for the package under test.
Intended for use inside `@student_test` or `@hidden_test` blocks.
"""
macro forbid(spec)
    return esc(:(@test SkeletonPackages._check_property($__module__, :forbid, $(QuoteNode(spec)))))
end

"""
    @assignment_requirements begin
        ...
    end

Group source-code requirements and reference-test metadata in a test file.
"""
macro assignment_requirements(block)
    return esc(block)
end

"""
    @reference_test f generator=1:30

Record reference-test metadata for the generated rubric. This is currently a
runtime no-op; reference-test execution is reserved for the grading harness.
"""
macro reference_test(args...)
    return :(nothing)
end

const ANNOTATION_OPENERS = Set(["@solution", "@starter", "@student_test", "@hidden_test"])
const TEACHER_ONLY_DIRS = Set([".git", "build", "solutions", ".julia", ".CondaPkg"])
const TRANSFORMED_EXTENSIONS = (".jl", ".md", ".toml", ".inc")

"""
    strip_teacher_annotations(text::AbstractString; mode=:student)

Transform annotated Julia source text.

For `mode = :student`, remove `@solution` and `@hidden_test` regions, and keep
the bodies of `@starter` and `@student_test` regions. For `mode = :teacher`,
keep `@solution`, `@student_test`, and `@hidden_test` bodies, and remove
`@starter` regions.

This implementation is intentionally line-oriented. Annotation macros must
appear on their own line as `@solution begin`, `@starter begin`,
`@student_test begin`, or `@hidden_test begin`.
"""
function strip_teacher_annotations(text::AbstractString; mode::Symbol=:student)
    lines = split(String(text), '\n'; keepempty=true)
    out = String[]
    i = 1
    while i <= length(lines)
        line = lines[i]
        stripped = strip(line)
        if stripped in ("@solution begin", "@starter begin", "@student_test begin", "@hidden_test begin")
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
        return macro_name in ("@starter", "@student_test")
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
        if endswith(s, " begin") || occursin(r"\bbegin\b", s)
            depth += count(==("begin"), split(s))
        end
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
