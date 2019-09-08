using Pkg

Pkg.update()
PackageSpec(url = "https://github.com/GenieFramework/Genie.jl",
            rev = "master") |> Pkg.add
PackageSpec(url = "https://github.com/GenieFramework/SearchLight.jl",
            rev = "master") |> Pkg.add
