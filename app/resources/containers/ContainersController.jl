module ContainersController
    using DockerCLI
    using SearchLight, Containers

    """
        Each function linked to an endpoint by the routes.jl file, is returning a
        Dict{String, Any} where if it only has side effects running without an output
        needed would return a Dict("status" => RAN_STATE) where RAN_STATE == "SUCCESS"
        if the required behavior was ran perfectly.
        If, otherwise, the function has an output to return, besides the 'status' attribute
        of the returned dictionary, a 'body' attribtue would be the output desired to be
        returned by the function/endpoint as a response.
    """

    """
        status()::Dict

    Return the status of the dockerized services containers, as for how many instances is
    running for each image/service, which are the ports occupied by each image, and by each
    instance. Returns an emty body if no instance is running.
    """
    function status()::Dict
        Dict("status" => "SUCCESS",
             "body" => DockerCLI.get_instances())
    end

    """
        regulate()
    
    A function used inside this controller to regulate the containers domain, that being
    said, it synchronizes the SQLite database of the load balancer with the Docker CLI
    output containers state. This behavior is useful whenever we need to avoid problems
    caused by unexpected shut-downs or interruptions of either docker containers, the load
    balancer, or even the server as a whole.
    """
    function regulate()
        function add_to_arraydict(key, value, dict)
            try
                push!(dict[key], value)
            catch
                dict[key] = [value]
            end
        end
        cont_dict::Dict{String, Array{Container}} = Dict()
        map(x -> add_to_arraydict(x.image, x, cont_dict), SearchLight.all(Container))
        up_filtered::Array{String} = filter(x -> cont_dict[x] |> length > 2,
                                            cont_dict |> keys |> collect)
        for img in cont_dict |> keys
            summ = sum(map(x -> x.requests, cont_dict[img]))
            if summ >= 50 * length(cont_dict[img])
                run_img(img, 1)
            end
            resting_cont::Array{Container} = filter(x -> x.requests == 0, cont_dict[img])
            for contain in resting_cont
                kill_inst(contain.image * string(contain.instance))
            end
        end
    end
    
    """
        kill_inst(instance::String)::Dict

    A function used to kill a docker service instance presuming it belongs to the services
    instances controlled by this load balancer. The instance string is the exact name of
    the running docker service instance.
    """
    function kill_inst(instance::String)::Dict
        exit_code = 0
        try
            exit_code = DockerCLI.kill_instance(instance)
        catch
            return Dict("status" => "UNKNOWN_FIELD_VALUE")
        end
        try
            SearchLight.find_one_by(Container,
                                    SQLWhereExpression("image || instance = ?",
                                                       instance)
                                   ) |> get |> SearchLight.delete
        catch
            println("Instance down but not registered to be deleted from registry!")
        end
        (exit_code != 0) && return Dict("status" => "INTERNAL_SERVER_ERROR")
        Dict("status" => "SUCCESS")
    end
    
    """
        kill_img(image::String)::Dict

    A function used to kill all instances of the docker image passed as an argument. Of
    course, it only kills instances of a controlled service, so doesn't have any side effect
    on other docker instances running on the server's docker service.
    """
    function kill_img(image::String)::Dict
        exit_code = 0
        try
            exit_code = DockerCLI.kill_img(image)
        catch
            return Dict("status" => "UNKNOWN_FIELD_VALUE")
        end
        for container in SearchLight.find_by(Container, :image, image)
            SearchLight.delete(container)
        end
        (exit_code != 0) && return Dict("status" => "INTERNAL_SERVER_ERROR")
        Dict("status" => "SUCCESS")
    end

    """
        run_img(image::String, nbr::Int)::Dict
    
    A function used to run 'nbr' instances of the 'image' specified. As it runs each instance,
    it subscribes the instance entry to the database so that it keeps track of its load in real time.
    """
    function run_img(image::String, nbr::Int)::Dict
        exit_code = 0
        (nbr == 0) && return Dict("status" => "success")
        try
            for n in 1:nbr
                exit_code += DockerCLI.run_instance(image)
            end
        catch
            return Dict("status" => "UNKNOWN_FIELD_VALUE")
        end
        (exit_code != 0) && return Dict("status" => "INTERNAL_SERVER_ERROR")
        open_containers::Dict{UInt16, UInt16} = DockerCLI.get_instances()[image]
        registered_ids::Array{UInt16} = map(x -> x.instance,
                                        SearchLight.find_by(Container, :image, image))
        not_registered_ids::Array{UInt16} = filter(x -> x ∉ registered_ids,
                                                   open_containers |> keys |> collect)
        for id in not_registered_ids
            Container(image = image,
                      instance = id,
                      port = open_containers[id],
                      requests = 0
                     ) |> SearchLight.save
        end
        Dict("status" => "SUCCESS")
    end

    """
        list_imgs()::Dict

    A function used to get a list of all images controlled by this load balancer.
    """
    function list_imgs()::Dict
        Dict("status" => "SUCCESS",
             "body" => DockerCLI.get_images())
    end

    """
        list_imgs(running::String)::Dict

    A function used to get a list of all images controlled by this load balancer
    ragarding its 'running' state, so either it returns all running images - any image
    that has at least one running instance - or all off images which have no child
    instances running.
    """
    function list_imgs(running::String)::Dict
        active = (running ∈ ["yes", "true"])
        Dict("status" => "SUCCESS",
             "body" => DockerCLI.get_images(active))
    end

    """
        list_ports()::Dict

    A function used to get a list of all occupied ports by instances/containers
    controlled by this load balancer.
    """
    function list_ports()::Dict
        Dict("status" => "SUCCESS",
             "body" => DockerCLI.get_ports())
    end

    """
        request_ports(images::Array{String})::Dict

    A function used to get a free instance port for each image/service needed - mentioned
    in the 'images' array passed as an argument. By free instance, it means any instance
    that didn't exceed its request subscriptions threshold. If none is provided, which may
    happen whenever no instance is running for that image, or no free instance exists in the
    running ones; that's when this function tries to run a new instance for that image, then
    returns its port. If by any way it couldn't return an instance port for a required image
    - for example, when the required image doesn't have a deployement-ready Docker image for
    it - ; it will return 0. So the front control consuming this service needs to handle this
    endpoint's response.
    When returning a free instance port, the load balancer database entry for that instance
    is also updated by incrementing its request subscription load.
    """
    function request_ports(images::Array{String})::Dict
        req_ports::Dict{String, UInt16} = Dict()
        for image in images
            container::Container = Container()
            result_count = SearchLight.count(Container,
                                             SQLQuery(where = 
                                                      SQLWhereEntity[SQLWhereExpression("image = ?",
                                                                                        image)]))
            if result_count == 0
                run_img(image, 1)
            end
            try
                container = SearchLight.find_one_by(Container,
                                                    :image, image,
                                                    order = SQLOrder(:requests, :asc)) |> get
                container.requests += 1
                SearchLight.save(container)
                req_ports[image] = container.port
            catch
                req_ports[image] = 0
            end
        end
        regulate()
        return Dict("status" => "SUCCESS",
                    "body" => req_ports)
    end

    """
        relieve_port(image::String, portr::UInt16)::String

    A function used to unsubscribe a request from a running instance so that it updates its
    database entry for any later regulation.
    """
    function relieve_port(image::String, port::UInt16)::String
        container::Container = Container()
        try
            container = SearchLight.find_one_by(Container,
                                                SQLWhereExpression("image = ? AND port = ?",
                                                                   image, port)) |> get
        catch
            return "UNKNOWN_FIELD_VALUE"
        end
        container.requests -= 1
        if container.requests <= 0
            kill_inst(image * string(container.instance))
        else
            SearchLight.save(container)
        end
        return "SUCCESS"
    end

    """
        relieve_ports(instances::Dict{String, UInt16})::Dict

    A function used to unsubscribe requests from passed instances, updating the load balancer
    database entries while doing so, and regulating/synchronizing its data with the server's
    Docker service.
    """
    function relieve_ports(instances::Dict{String, UInt16})::Dict
        result::Dict{String, String} = Dict()
        for (image, port) in instances
            result[image] = relieve_port(image, port)
        end
        return result
    end
end
