using Documenter
using SkeletonPackages

makedocs(;
    sitename = "SkeletonPackages.jl",
    modules = [SkeletonPackages],
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = nothing,
        repolink = "https://github.com/mroughan/SkeletonPackages.jl",
    ),
    pages = [
        "Intro" => "index.md",
        "Pipeline" => "pipeline.md",
        "Additional Details" => "details.md",
        "Requirements" => "requirements.md",
        "API" => "api.md",
    ],
    checkdocs = :exports,
    remotes = nothing,
)

deploydocs(; repo = "github.com/mroughan/SkeletonPackages.jl.git", devbranch = "main", push_preview = true)
