using StringProcessingAssignment
using SkeletonizePackage
using Test

@student_test begin
    @marks 2 "word_frequencies counts correctly for a simple sentence" id="public-wf-basic"
    freqs = word_frequencies("the cat sat on the mat")
    @test first(freqs).first == "the"
    @test first(freqs).second == 2
    @test length(freqs) == 5
end

@student_test begin
    @marks 1 "word_frequencies handles case and punctuation" id="public-wf-case"
    freqs = word_frequencies("Hello, hello! HELLO.")
    @test length(freqs) == 1
    @test first(freqs) == ("hello" => 3)
end

@hidden_test begin
    @marks 2 "word_frequencies output is sorted correctly" id="hidden-wf-sort"
    freqs = word_frequencies("b a b a a")
    @test first(freqs).first == "a"
    @test first(freqs).second == 3
    # alphabetical tie-breaking
    @test [p.first for p in freqs] == ["a", "b"]
end

@hidden_test begin
    @marks 1 "top_words returns the correct number of entries" id="hidden-top-n"
    @test length(top_words("a b c a b a", 2)) == 2
    @test first(top_words("x x y y z", 1)).first == "x"
end

@hidden_test begin
    @marks 2 "word_frequencies matches reference on varied inputs" id="hidden-ref-wf"
    @reference_test word_frequencies generator=["hello world hello", "a b a c a b", ""]
end

@assignment_requirements begin
    @require exported(word_frequencies) marks=1 id="interface-wf-export" "exports word_frequencies"
    @require exported(top_words)        marks=1 id="interface-tw-export" "exports top_words"
    @require docstring(word_frequencies) marks=1 id="style-wf-docstring" "documents word_frequencies"
    @require docstring(top_words)        marks=1 id="style-tw-docstring" "documents top_words"
    @require loop(word_frequencies)      marks=1 id="impl-wf-loop" "uses a loop in word_frequencies"
    @forbid imports(DataFrames) zero_marks=true "does not use a shortcut package"
end
