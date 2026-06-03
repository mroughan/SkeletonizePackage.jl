module StringProcessingAssignment

using SkeletonizePackage

export word_frequencies, top_words

"""
    word_frequencies(text::AbstractString) -> Vector{Pair{String,Int}}

Return a vector of `word => count` pairs sorted by frequency descending, then
alphabetically for ties. Words are lowercased and all non-letter characters are
stripped before counting.

# Example

```julia
julia> word_frequencies("the cat sat on the mat")
6-element Vector{Pair{String, Int64}}:
 "the" => 2
 "cat" => 1
 "mat" => 1
 "on" => 1
 "sat" => 1
 ...
```
"""
function word_frequencies(text::AbstractString)
    @solution begin
        counts = Dict{String,Int}()
        for raw in split(lowercase(text))
            word = replace(raw, r"[^a-z]" => "")
            isempty(word) && continue
            counts[word] = get(counts, word, 0) + 1
        end
        return sort!(collect(counts); by=p -> (-p.second, p.first))
    end
    @scaffolding begin
        error("TODO: implement word_frequencies")
    end
end

"""
    top_words(text::AbstractString, n::Int) -> Vector{Pair{String,Int}}

Return the `n` most frequent word-count pairs in `text`, in the same order as
`word_frequencies`. If `n` exceeds the number of distinct words, all words are
returned.

# Example

```julia
julia> top_words("to be or not to be", 2)
2-element Vector{Pair{String, Int64}}:
 "be" => 2
 "to" => 2
```
"""
function top_words(text::AbstractString, n::Int)
    @solution begin
        return first(word_frequencies(text), n)
    end
    @scaffolding begin
        error("TODO: implement top_words")
    end
end

end
