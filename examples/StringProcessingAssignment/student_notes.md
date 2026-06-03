# String Processing Assignment

In this assignment you will implement two functions for analysing word frequencies
in text.

## Task

Implement `word_frequencies(text)` and `top_words(text, n)` in
`src/StringProcessingAssignment.jl`.

**`word_frequencies(text)`** should:
- Split the input text into words on whitespace.
- Lowercase every word and strip all non-letter characters.
- Count how often each word appears.
- Return a `Vector{Pair{String,Int}}` sorted by count descending, then
  alphabetically for equal counts.
- Ignore empty strings that arise from stripping (e.g. a word that is entirely
  punctuation).

**`top_words(text, n)`** should return the first `n` pairs from
`word_frequencies(text)`.

## Hints

- `split(text)` splits on whitespace.
- `lowercase(word)` lowercases a string.
- `replace(word, r"[^a-z]" => "")` removes non-letter characters.
- A `Dict{String,Int}` is a good way to accumulate counts.
- `sort!` with a `by` keyword sorts in-place.

## Submission

Run the tests with `julia --project=. -e 'using Pkg; Pkg.test()'` before submitting.
