This metapackage operates on another Julia package. It should allow a lecturer to
write a package, called `X.jl` here, and include annotations such as `@solution`
and `@hidden_test` that identify parts of the package that should be hidden from
students.

`SkeletonizePackage.jl` should take `X.jl` and create `Y.jl`, a functional scaffolding
package with the hidden components removed or replaced. The scaffolding can include
partial functions, partial tests, partial documentation, and other scaffolding
that helps students without handing them the solution.

A student then takes `Y.jl` and tries to recreate the intended behaviour of
`X.jl`; call the submitted package `Z.jl`. The teacher would like to automate
testing that `Z.jl` implements the required interface and behaviour. That may
include comparing a set of tests provided to the student with a set of tests that
were hidden from the student, along with other checks that `X.jl` and `Z.jl` are
functionally equivalent.

## Workflow 

```
X.jl  --teacher solution package
  |
  |  strip / transform / reveal selected parts
  v
Y.jl  --student skeleton
  |
  |  student completes it
  v
Z.jl  --student submission package

Then compare:
    X.jl ≈ Z.jl
using public tests + hidden tests + behavioural checks.
```

## Annotations

```
@solution      # teacher-only implementation
@scaffolding       # replacement shown to students
@hidden_test   # tests used for grading but not shown
@student_test  # tests included in Y.jl
```

Possible future annotations include `@hint` for student-facing feedback and
`@rubric` for grading metadata. The implementation should add these only when
there is a clear transformation and reporting story for them.

## Constraints

1. The package should not try to be a full Julia parser/reformatter. Instead, it should define a small annotation language that is easy to recognise and transform.
2. Avoid making @hidden merely deleting code, because deleting code may leave broken syntax. 
3. Don't try to test if X.jl and Z.jl (the students solution) are exactly the same.

## Checks

Automated assessment of student work against the required work is
included here.

In general such assessment should be
  + transparent to students (they know what is tested)
  + pedagogically meaningful
  + technically implementable 
  + hard to game
  + provide feedback about problems

There are two parts of assessment

  1. Specific value tests (as in standard unit testing, though using
     AnnotatedTests.jl rather than Test for more feedback). Some of
     these can be student visible, and some hidden. Some of these
     tests may use tests against the reference function.

  2. Behavioural/property testing of the code, eg testing if a
     function is recursive, or its API complies with a
     specification. It is expected that the specified requirements
     will be visible to students, if not the outcomes of testing of
     these requirements.

The rubric for the testing IS the skeleton provided to the student.

## Notes

We are also building a separate package called AnnotatedTests to allow
more meaningful feedback from tests, but for the moment restrict
testing to the stdlib Test. 

## Current implementation path

1. Read Julia source files from X.jl as text.
2. Validate annotated regions and report both transformation errors and
   skeleton-design warnings. For Julia files, parse the source before and after
   annotation removal to catch broken generated code early.
3. Transform/remove/replace annotated syntax.
4. Write a new package directory for Y.jl, without replacing an existing
   destination unless `force=true`.
5. Run tests of Z.jl in isolated Julia processes and return structured results.

Use an INC file to configure the overall package/example. The configuration
lives in the INI-style metadata block defined by INCspec and read/written by
IncCSV.jl, eg,

```text
---
[assignment]
name = "SortingAssignment"
student_package = "SortingAssignmentStudent"
source_path = "examples/SortingAssignment"
student_path = "SortingAssignmentStudent"
force = false
validate = true
instructions_path = "student_notes.md"

[visibility]
default = "student"

[grading]
public_tests = true
hidden_tests = true
reference_tests = true
---
config
assignment
```
