module ShortcutPolicyAssignment

using SkeletonizePackage

export normalize_words

"""
    normalize_words(words)

Strip whitespace from each word, lowercase it, and discard empty words.
"""
function normalize_words(words)
    @solution begin
        return [lowercase(strip(word)) for word in words if !isempty(strip(word))]
    end
    @scaffolding begin
        error("TODO: normalize each word without using a table/dataframe package")
    end
end

end
