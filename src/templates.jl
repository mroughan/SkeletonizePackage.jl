"""
    create_assignment(path; name=basename(path), force=false)

Create a small annotated teacher package template.

The template includes `Project.toml`, `src/`, `test/`, and a
`SkeletonPackages.inc` that can be used with `generate_student_package`.
"""
function create_assignment(path::AbstractString; name::AbstractString=basename(path), force::Bool=false)
    root = abspath(path)
    if ispath(root)
        force || throw(ArgumentError("assignment path already exists: $path (pass force=true to replace it)"))
        rm(root; recursive=true, force=true)
    end
    module_name = _module_name(name)
    uuid = string(Base.UUID(rand(UInt128)))
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    write(joinpath(root, "Project.toml"), """
name = "$module_name"
uuid = "$uuid"
version = "0.1.0"

[deps]
SkeletonPackages = "c8e6063d-6c4e-4aa4-bd9b-3a45f2ad7dd1"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
""")
    write(joinpath(root, "src", "$module_name.jl"), """
module $module_name

using SkeletonPackages

export answer

\"\"\"
    answer()

Return the answer for this assignment.
\"\"\"
function answer()
    @solution begin
        return 42
    end
    @starter begin
        error("TODO: implement answer")
    end
end

end
""")
    write(joinpath(root, "test", "runtests.jl"), """
using $module_name
using SkeletonPackages
using Test

@student_test begin
    @marks 1 "answer returns an integer"
    @test answer() isa Integer
end

@hidden_test begin
    @marks 2 "answer returns the required value"
    @test answer() == 42
end
""")
    write(joinpath(root, "student_notes.md"), """
# Assignment Notes

Replace this section with instructions that are specific to this exercise.

For example, describe the problem, the functions students should implement, any
restrictions on allowed Julia features or packages, and what they should submit.
""")
    writeinc(
        joinpath(root, "SkeletonPackages.inc"),
        [(config="assignment",)];
        metadata=Dict(
            "assignment" => Dict(
                "reference_path" => ".",
                "skeleton_path" => "../$(module_name)Student",
                "mode" => "student",
                "force" => "false",
                "validate" => "true",
                "instructions_path" => "student_notes.md",
            ),
        ),
    )
    return root
end

function _module_name(name)
    cleaned = replace(String(name), r"[^A-Za-z0-9_]" => "")
    isempty(cleaned) && throw(ArgumentError("name must contain at least one letter or digit"))
    occursin(r"^[A-Za-z_]", cleaned) ? cleaned : "Assignment$cleaned"
end

function _write_student_instructions(dst::AbstractString; instructions_path::Union{Nothing, AbstractString}=nothing)
    package_name = _project_name(dst)
    exercise_instructions = _exercise_instructions(instructions_path)
    write(joinpath(dst, "STUDENT_INSTRUCTIONS.md"), """
# Getting Started with `$package_name`

This is a Julia package skeleton for an assignment. Your job is to fill in the
starter code, run the tests, and submit the completed package as instructed by
your teacher.

## Package Layout

A standard Julia package usually has this structure:

```text
$package_name/
  Project.toml          package name, UUID, dependencies, and compatibility
  src/                  source code for the package
  test/                 tests you can run while working
  README.md             assignment-specific notes, if provided
```

Most assignments ask you to edit files under `src/`. Tests usually live in
`test/runtests.jl`. Do not change `Project.toml` unless the assignment or teacher
explicitly asks you to add dependencies.

## Opening Julia in the Package Environment

Open a terminal in this package directory. Then start Julia with the local package
environment active:

```bash
julia --project=.
```

Inside Julia, you can check that the active project is this folder:

```julia
using Pkg
Pkg.status()
```

## Installing Dependencies

The first time you use the package, install the dependencies recorded in
`Project.toml`:

```julia
using Pkg
Pkg.instantiate()
```

If your teacher asks you to add a package, activate this environment first, then
use:

```julia
using Pkg
Pkg.add("PackageName")
```

## Running Tests

From the terminal:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Or from inside Julia:

```julia
using Pkg
Pkg.test()
```

Tests are your fastest feedback loop. Run them after each small change.

## Editing and Reloading Code

Edit the files in `src/`, save them, and rerun the tests. If you are working in a
Julia session and want to try functions interactively, restart Julia after edits
or use a package such as Revise.jl if you already know it.

To load this package in the active environment:

```julia
using $package_name
```

## Common Problems

- `Package $package_name not found`: start Julia with `julia --project=.` from
  this package directory.
- Missing dependency errors: run `using Pkg; Pkg.instantiate()`.
- Tests still failing: read the first failing test and error message carefully,
  then work on the smallest function related to that failure.
- Changed the wrong environment: close Julia, return to this folder, and restart
  with `julia --project=.`

## Submitting

Before submitting, run the tests from a fresh Julia process:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Submit the completed package folder according to your teacher's instructions.
$(exercise_instructions)
""")
end

function _exercise_instructions(instructions_path::Union{Nothing, AbstractString})
    instructions_path === nothing && return ""
    isfile(instructions_path) || throw(ArgumentError("instructions_path is not a file: $instructions_path"))
    text = read(instructions_path, String)
    transformed = strip_teacher_annotations(text; mode=:student)
    return """

## Exercise-Specific Instructions

$(rstrip(transformed))
"""
end

function _project_name(path::AbstractString)
    project = joinpath(path, "Project.toml")
    if isfile(project)
        data = TOML.parsefile(project)
        return String(get(data, "name", basename(path)))
    end
    return basename(path)
end
