# What You Can Build

`SkeletonizePackage.jl` is designed for teachers who want the convenience of a
single source of truth. You write one annotated reference package: the complete
solution, the public tests students should see, the hidden checks they should
not see, and the rubric that explains how the work will be assessed. From that
one package, `SkeletonizePackage.jl` can create the student version, validate
the assignment design, and grade submitted packages against the original
reference.

## Start From a Working Assignment

You do not have to remember the whole annotation system before making your first
assignment. `create_assignment(...)` and the `init` command create a ready-to-edit
teacher package with source files, public and hidden tests, assignment notes, a
README, and a `SkeletonizePackage.inc` configuration file. The scaffold includes
small examples of the main patterns, so you can replace the sample exercise with
your own rather than starting from a blank directory.

## Write the Teacher Version Once

The central idea is simple: keep the teacher's complete version in one place and
mark which parts belong to students. Put the reference implementation in
`@solution`, put the starter code in `@scaffolding`, wrap visible tests in
`@student_test`, and wrap private grading tests in `@hidden_test`. When you
generate the skeleton, students receive the scaffolding and public tests, while
solutions and hidden tests stay in the reference package.

The generated skeleton is still an ordinary Julia package. Students can open it
in their editor, instantiate it, run `Pkg.test()`, and submit it using normal
Julia workflows. The transformation handles Julia source, Markdown, TOML, and
INC configuration files, while leaving teacher-only material such as `.git`,
`build`, and `solutions` out of the student package.

## Give Students Clear Instructions and a Rubric

A generated skeleton can include much more than TODOs. `SkeletonizePackage.jl`
writes a `STUDENT_INSTRUCTIONS.md` file with package-workflow guidance and any
exercise-specific notes you provide. It also writes `RUBRIC.md` from the marks
embedded in your tests and property checks, so students can see what matters
without seeing hidden test code.

AI-use expectations are documented too. The generated `AGENTS.md` records
whether AI assistance is `forbidden`, `recorded`, or `allowed`, making that
policy explicit inside the submitted package rather than buried in a separate
course page.

## Turn Tests Into Feedback

Public and hidden tests can carry marks with `@marks`, so the tests do not just
pass or fail: they become named grading criteria. Stable `id="..."` values let
the same criterion appear consistently in the student rubric, teacher grading
plan, feedback reports, and CSV mark rows.

For behavioural checks, `@reference_test` lets you compare a submitted function
against the teacher implementation. You can provide explicit inputs or generate
input cases with `generator=...`. Reference and submission packages are evaluated
in separate Julia processes, which avoids module-name collisions when both
packages define the same functions.

## Check the Shape of Student Code

Sometimes the answer matters, and sometimes the way students get there matters
too. `@assignment_requirements` lets you require or forbid source properties
with `@require` and `@forbid`. You can check for exported functions, signatures,
docstrings, recursion, loops, comments, line-count limits, imports, calls,
operators, globals, and side-effect patterns.

These checks can be gentle rubric items or hard gates. Add `marks=N` when a
property should contribute points, or use `zero_marks=true` for serious shortcut
or integrity violations that should zero the whole assignment.

## Validate Before You Distribute

Before generating a skeleton, `validate_reference_package(...)` can catch common
assignment-design problems: unsupported annotation forms, missing test
structure, parsing issues, and other situations that would confuse the
transformation. Generation can be configured to stop when validation reports an
error, so mistakes are caught before students receive the package.

## Keep the Teacher Organised

The package also writes teacher-facing material that stays out of the student
skeleton. `GRADING_PLAN.md` records public and hidden criteria, stable IDs,
source locations, points, and zero gates. `TEACHER_CHECKLIST.md` gives a compact
preparation, skeleton-inspection, and grading checklist. Those files are useful
when an assignment is reused, shared with tutors, or debugged after a semester
has started.

## Grade Submissions at Class Scale

After students submit completed packages, use `grade_submission(...)` or the
`grade` command to run the public, hidden, property, and reference-oracle checks
against each submission. Grading produces a Markdown feedback report for the
student and a CSV row that can be appended to a class marks spreadsheet. The
programmatic result also returns per-criterion `CriterionResult` values, so you
can build custom reporting or batch workflows on top.

## Use Julia or the Command Line

Everything can be driven from Julia functions, and the common workflow is also
available from the command line:

```bash
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- init MyAssignment --ai-policy recorded
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- validate MyAssignment
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- generate MyAssignment MyAssignmentSkeleton --force
julia --project -e 'using SkeletonizePackage; exit(SkeletonizePackage.main())' -- grade MyAssignment MySubmission --student-id s123 --report s123-feedback.md --csv marks.csv
```

The repository's own checks are split into ordinary package tests, Aqua quality
checks, and JET static analysis, so failures are easier to interpret when
maintaining the package itself.
