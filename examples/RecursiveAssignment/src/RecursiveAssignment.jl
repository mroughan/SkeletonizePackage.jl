module RecursiveAssignment

using SkeletonizePackage

export fib

"""
    fib(n)

Return the nth Fibonacci number for `n >= 0`.
"""
function fib(n)
    @solution begin
        n < 0 && throw(ArgumentError("n must be nonnegative"))
        n <= 1 && return n
        return fib(n - 1) + fib(n - 2)
    end
    @scaffolding begin
        error("TODO: implement fib recursively")
    end
end

end
