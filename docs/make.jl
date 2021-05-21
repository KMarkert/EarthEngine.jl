push!(LOAD_PATH,"../src/")

using Documenter, EarthEngine

pages = [
    "Home" => "index.md",
    "Usage" => "usage.md",
    "API" => "api.md",
]

makedocs(;
    modules = [EarthEngine],
    authors = "Kel Markert",
    repo = "https://github.com/KMarkert/EE.jl/blob/{commit}{path}#L{line}",
    sitename = "EarthEngine.jl",
    # format = Documenter.HTML(;
    #     prettyurls = get(ENV, "CI", "false") == "true",
    #     canonical = "https://deltares.github.io/Wflow.jl",
    #     assets = String[],
    # ),
    pages = pages,
)

deploydocs(; 
    deps = Deps.pip("earthengine-api"),
    repo = "github.com/KMarkert/EE.jl.git",
    devbranch = "main"
)
