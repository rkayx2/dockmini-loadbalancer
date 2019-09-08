using Genie.Router, Genie.Requests
using ContainersController

route("/api") do
    json(ContainersController.status())
end

route("/api", method = POST) do
    services::Array{String} = jsonpayload()["services"]
    ContainersController.request_ports(services) |> json
end

route("/api/done", method = POST) do
    services::Dict{String, UInt16} = jsonpayload()
    ContainersController.relieve_ports(services) |> json
end

route("/api/kill") do
    instance = haskey(@params, :instance) ? @params(:instance) : nothing
    image = haskey(@params, :image) ? @params(:image) : nothing
    (instance == image == nothing) && return Dict("status" => "MISSING_FIELD_VALUE")
    !xor(instance == nothing, image == nothing) && return Dict("status" => "BAD_REQUEST_FORMAT")
    if image == nothing
        json(ContainersController.kill_inst(instance))
    else
        json(ContainersController.kill_img(image))
    end
end

route("/api/run") do
    image = haskey(@params, :image) ? @params(:image) : nothing
    nbr_inst = nothing
    if haskey(@params, :nbr)
        try
            nbr_inst = parse(Int, @params(:nbr))
        catch
            return Dict("status" => "BAD_FIELD_FORMAT")
        end
    end
    (image == nothing) && return json(Dict("status" => "MISSING_FIELD_VALUE"))
    (nbr_inst == nothing) && return json(ContainersController.run_img(image, 1))
    json(ContainersController.run_img(image, nbr_inst))
end

route("/api/images") do
    running = haskey(@params, :running) ? @params(:running) : nothing
    (running == nothing) && return json(ContainersController.list_imgs())
    (running ∉ ["yes", "true", "false", "no"]) && return json(Dict("status" => "UNKNOWN_FIELD_VALUE"))
    json(ContainersController.list_imgs(running))
end

route("/api/ports") do
    json(ContainersController.list_ports())
end

