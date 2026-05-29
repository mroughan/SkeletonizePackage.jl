using ConfiguredAssignment
using SkeletonPackages
using Test

@assignment_requirements begin
    @require exported(normalize_name)
    @require exists(normalize_name)
    @require signature(normalize_name, 1)
    @require docstring(normalize_name)
    @forbid imports(CSV)
end

@student_test begin
    @marks 1 "lowercases a simple name"
    @test normalize_name("Ada") == "ada"
    @marks 2 "trims surrounding whitespace before lowercasing"
    @test normalize_name("  Grace  ") == "grace"
end

@hidden_test begin
    @marks 1 "handles tab and newline whitespace"
    @test normalize_name("\tKatherine\n") == "katherine"
end
