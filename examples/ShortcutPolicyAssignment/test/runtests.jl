using ShortcutPolicyAssignment
using SkeletonizePackage
using Test

@student_test begin
    @marks 1 "normalizes simple words" id="words-simple"
    @test normalize_words([" Ada ", "LOVELACE"]) == ["ada", "lovelace"]
end

@hidden_test begin
    @marks 2 "drops empty entries and handles mixed whitespace" id="words-whitespace"
    @test normalize_words(["  Grace", "", "\tHOPPER\n"]) == ["grace", "hopper"]
end

@assignment_requirements begin
    @require signature(normalize_words, 1) marks=1 id="words-signature" "keeps the required interface"
    @require docstring(normalize_words) marks=1 id="words-docstring" "documents normalize_words"
    @forbid imports(DataFrames) zero_marks=true "does not use a table package shortcut"
end
