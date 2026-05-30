module SkeletonPackages

using IncCSV: metadata, readinc, writeinc
using Serialization
using TOML

export @solution, @starter, @student_test, @hidden_test, @marks,
       @require, @forbid, @assignment_requirements, @reference_test,
       AssignmentConfig, GradeResult, PropertyCheckResult, ReferenceTestResult,
       ValidationIssue, ValidationReport, create_assignment,
       generate_skeleton_package, grade_submission, main, read_assignment_config,
       strip_reference_annotations, validate_reference_package

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
