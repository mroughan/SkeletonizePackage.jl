module ConfiguredAssignment

using SkeletonizePackage

export normalize_name

"""
    normalize_name(name)

Trim surrounding whitespace and return a lowercase name.
"""
function normalize_name(name)
    @solution begin
        return lowercase(strip(name))
    end
    @scaffolding begin
        error("TODO: trim whitespace and lowercase the name")
    end
end

end
