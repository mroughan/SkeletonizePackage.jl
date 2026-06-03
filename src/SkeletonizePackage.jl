module SkeletonizePackage

using IncCSV: metadata, readinc, writeinc
using Serialization
using TOML

export @solution, @scaffolding, @student_test, @hidden_test, @marks,
       @require, @forbid, @assignment_requirements, @reference_test,
       AssignmentConfig, CriterionResult, GradeResult, PropertyCheckResult, ReferenceTestResult,
       ValidationIssue, ValidationReport, create_assignment,
       generate_skeleton_package, grade_submission, main, read_assignment_config,
       strip_reference_annotations, validate_reference_package, write_grading_plan,
       write_teacher_checklist

include("annotations.jl")
include("config.jl")
include("properties.jl")
include("rubric.jl")
include("validation.jl")
include("templates.jl")
include("generation.jl")
include("grading.jl")
include("cli.jl")

end # module
