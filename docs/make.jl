using Pkg

Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "..")))
Pkg.instantiate()

using Documenter
using SkeletonizePackage

DocMeta.setdocmeta!(SkeletonizePackage, :DocTestSetup, :(using SkeletonizePackage); recursive=true)

makedocs(;
    modules = [SkeletonizePackage],
    authors="Matthew Roughan <matthew.roughan@adelaide.edu.au>",
    sitename = "SkeletonizePackage.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        repolink = "https://github.com/mroughan/SkeletonizePackage.jl",
        canonical="https://mroughan.github.io/SkeletonizePackage.jl",
        assets=String[],
    ),
    pages = [
        "Intro" => "index.md",
        "Features" => "features.md",
        "Pipeline" => "pipeline.md",
        "Additional Details" => "details.md",
        "Requirements" => "requirements.md",
        "API" => "api.md",
    ],
    remotes = nothing,
    checkdocs = :exports,
) 

deploydocs(;
           repo = "github.com/mroughan/SkeletonizePackage.jl",
           devbranch = "main",
           push_preview = true
          )
