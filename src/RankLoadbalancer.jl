module RankLoadbalancer

using Genie, Genie.Router, Genie.Renderer, Genie.AppServer

function main()
  Base.eval(Main, :(const UserApp = RankLoadbalancer))

  include(joinpath("..", "genie.jl"))

  Base.eval(Main, :(const Genie = RankLoadbalancer.Genie))
  Base.eval(Main, :(using Genie))
end; main()

end
