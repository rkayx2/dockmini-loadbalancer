  cd(@__DIR__)
  using Pkg
  pkg"activate ."
  pkg"build"
  pkg"precompile"

  function main()
    include(joinpath("src", "RankLoadbalancer.jl"))
  end; main()
