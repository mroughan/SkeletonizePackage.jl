module ConfiguredAssignment

using SkeletonPackages

export normalize_name

"""
    normalize_name(name)

Trim surrounding whitespace and return a lowercase name.
"""
function normalize_name(name)
    @solution begin
        return lowercase(strip(name))
    end
    @starter begin
        error("TODO: trim whitespace and lowercase the name")
    end
end

end
