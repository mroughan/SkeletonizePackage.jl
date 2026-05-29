using Pkg

Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "..")))
Pkg.instantiate()

using Documenter
using SkeletonPackages

DocMeta.setdocmeta!(SkeletonPackages, :DocTestSetup, :(using SkeletonPackages); recursive=true)

makedocs(;
    modules = [SkeletonPackages],
    authors="Matthew Roughan <matthew.roughan@adelaide.edu.au>",
    sitename = "SkeletonPackages.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        repolink = "https://github.com/mroughan/SkeletonPackages.jl",
        canonical="https://mroughan.github.io/SkeletonPackages.jl",
        assets=String[],
    ),
    pages = [
        "Intro" => "index.md",
        "Pipeline" => "pipeline.md",
        "Additional Details" => "details.md",
        "Requirements" => "requirements.md",
        "API" => "api.md",
    ],
    remotes = nothing,
    checkdocs = :exports,
) 

deploydocs(;
           repo = "github.com/mroughan/SkeletonPackages.jl",
           devbranch = "main",
           push_preview = true
          )
