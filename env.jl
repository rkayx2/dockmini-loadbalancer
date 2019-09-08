# if the environment is not defined, use this default
const GENIE_ENV = "prod"

if ! haskey(ENV, "GENIE_ENV")
  ENV["GENIE_ENV"] = GENIE_ENV
end
if ! haskey(ENV, "NWORKERS") && in("s", ARGS)
  ENV["NWORKERS"] = 1
end
