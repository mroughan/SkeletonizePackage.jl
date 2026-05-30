module ReferenceOracleAssignment

using SkeletonPackages

export clamp01

"""
    clamp01(x)

Clamp `x` into the closed interval `[0, 1]`.
"""
function clamp01(x)
    @solution begin
        return clamp(x, 0, 1)
    end
    @starter begin
        error("TODO: implement clamp01")
    end
end

end
