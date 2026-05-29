module SkeletonPackages

using IncCSV: metadata, readinc, writeinc
using TOML

export @solution, @starter, @student_test, @hidden_test, @marks,
       @require, @forbid, @assignment_requirements, @reference_test,
       AssignmentConfig, GradeResult, ValidationIssue, ValidationReport,
       create_assignment, generate_skeleton_package, generate_student_package,
       grade_submission, main, read_assignment_config, strip_teacher_annotations,
       validate_teacher_package

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
