module SortingAssignment

using SkeletonPackages

export mysort

"""
    mysort(xs)

Return a sorted copy of `xs` without mutating the input collection.

# Examples

```jldoctest
julia> mysort([3, 1, 2])
3-element Vector{Int64}:
 1
 2
 3
```
"""
function mysort(xs)
    @solution begin
        return sort(xs)
    end
    @starter begin
        error("TODO: implement mysort")
    end
end

end
