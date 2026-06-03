# Feature List

`SkeletonizePackage.jl` supports the full teaching-package lifecycle: creating a
teacher reference package, generating a student skeleton, and grading a student
submission against the original reference.

## Step 0 Scaffolding

- Create a new teacher reference package with `create_assignment(...)` or the
  `init` CLI command.
- Generate a ready-to-edit package containing source files, tests, assignment
  notes, a README, and a `SkeletonizePackage.inc` configuration file.
- Include examples of the main annotation and grading features so teachers can
  edit from a working starting point.

## Reference to Skeleton Transformation

- Transform a teacher reference package into a student skeleton package with
  `generate_skeleton_package(...)`.
- Keep scaffolding code and public tests for students.
- Remove teacher-only solutions and hidden tests from the generated skeleton.
- Transform Julia source, Markdown, TOML, and INC configuration files.
- Skip teacher-only directories such as `.git`, `build`, and `solutions`.

## Annotation Language

- Use `@solution` for teacher-only reference implementations.
- Use `@scaffolding` for code shown to students.
- Use `@student_test` for public tests included in the skeleton.
- Use `@hidden_test` for private grading tests kept in the reference package.
- Use `@assignment_requirements` to group broader source and behavioural
  requirements.

## Rubric and Marking

- Attach marks to public or hidden tests with `@marks`.
- Generate a student-facing `RUBRIC.md` from embedded rubric entries.
- Assign marks directly to required or forbidden source properties with
  `marks=N`.
- Attach stable rubric identifiers with `id="..."` so feedback and grading
  plans can refer to criteria consistently.
- Mark serious integrity or shortcut violations with `zero_marks=true`, which
  makes a failed requirement zero the whole assignment.
- Summarize marks by criterion, category, and total in grading reports and CSV
  rows.

## Code Property Checks

- Require source features with `@require`, such as exported functions,
  signatures, docstrings, recursion, loops, comments, or line-count limits.
- Forbid source features with `@forbid`, such as imports, calls, operators,
  globals, or side-effect patterns.
- Use property checks as public rubric criteria, hidden grading criteria, or
  assignment-wide requirements.

## Reference Oracle Tests

- Compare a submitted function against the teacher reference implementation
  with `@reference_test`.
- Generate test inputs with `generator=...` or provide explicit input lists.
- Evaluate reference and submission packages in separate Julia processes to
  avoid module-name collisions.

## Student Skeleton Outputs

- Generate `STUDENT_INSTRUCTIONS.md` with package workflow guidance and optional
  exercise-specific notes.
- Generate `RUBRIC.md` from embedded marks and property requirements.
- Generate `AGENTS.md` from the configured AI-use policy:
  `forbidden`, `recorded`, or `allowed`.
- Preserve the generated skeleton as a normal Julia package that students can
  open, edit, instantiate, test, and submit.

## Teacher-Facing Outputs

- Write `GRADING_PLAN.md` with stable IDs, public and hidden criteria, source
  locations, points, and zero gates.
- Write `TEACHER_CHECKLIST.md` with preparation, skeleton inspection, and
  grading checks.
- Keep teacher-facing files out of generated student skeletons.

## Configuration

- Configure generation with `SkeletonizePackage.inc`.
- Use the INI-style metadata format defined by INCspec and read/written through
  IncCSV.jl.
- Configure reference and skeleton paths, generation mode, validation, force
  behaviour, exercise notes, and AI policy.

## Validation and Feedback

- Validate reference packages before generation with `validate_reference_package`.
- Detect unsupported annotation forms, missing test structure, parsing problems,
  and common teaching-design issues.
- Block skeleton generation on validation errors when validation is enabled.

## Quality Checks

- Run ordinary package tests on supported Julia versions.
- Run Aqua quality checks separately from the functional test suite.
- Run JET static analysis as a separate check on Julia 1.12.x only, while the
  package itself remains compatible with Julia 1.10.

## Grading Outputs

- Grade student submissions with `grade_submission(...)` or the `grade` CLI
  command.
- Produce a Markdown feedback report for students.
- Produce a CSV header and row suitable for building a class marks spreadsheet.
- Include public, hidden, property, reference-test, and total marks in grading
  summaries.
- Return per-criterion `CriterionResult` values from `grade_submission`.

## Planned Work

- See `TODO.md` for the intentionally deferred syntax-aware property-checking
  work and batch submission grading plan.

## Command-Line Workflow

- `init`: create the step 0 teacher scaffold.
- `validate`: check the teacher reference package.
- `generate`: create the student skeleton package.
- `grade`: grade a student submission and write feedback/marks outputs.
