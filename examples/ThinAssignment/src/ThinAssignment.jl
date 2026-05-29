module ThinAssignment

using SkeletonPackages

export double_it

"""
    double_it(x)

Return twice `x`.
"""
function double_it(x)
    @solution begin
        return 2x
    end
    @starter begin
        error("TODO: implement double_it")
    end
end

end
