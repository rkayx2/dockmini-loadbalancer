module DockerCLI
    using ContainerConfig

    """
        get_images()::Array{String}

    Return a list/array of the containers images (their callable names: without the "[CONTAINER_REPOSITORY_PREFIX]/"
    prefix) found on the system.
    """
    function get_images()::Array{String}
        raw_names::Array{String} = read(`docker images --format "{{.Repository}}"`, String) |> split
        filter!(x -> occursin(CONTAINER_REPOSITORY_PREFIX, x), raw_names)
        isempty(raw_names) && return []
        map(x -> replace(x, CONTAINER_REPOSITORY_PREFIX => ""), raw_names)
    end

    """
        get_images(running::Bool)::Array{String}

    Returns a list/array of the active|non-active images according to the 'running' argument (having
    at least 1 instance running).
    """
    function get_images(running::Bool)::Array{String}
        raw_output::Array{String} = read(`docker ps --format "{{.Image}}" --filter "name=$CONTAINER_SERVICE_SUFFIX"`, String) |> split |> unique
        isempty(raw_output) && running && return []
        running_imgs::Array{String} = map(x -> x[findfirst(isequal('/'), x) + 1 : end], raw_output)
        running && return running_imgs
        imgs::Array{String} = get_images()
        filter(x -> x ∉ running_imgs, imgs)
    end

    """
        get_ports()::Array{UInt16}

    Returns a list/array of the active ports occupied by the containers instances.
    """
    function get_ports()::Array{UInt16}
        raw_output::Array{String} = read(`docker ps --format "{{.Ports}}" --filter "name=$CONTAINER_SERVICE_SUFFIX"`, String) |> split
        isempty(raw_output) && return []
        map(x -> parse(UInt16,
                       x[findfirst(isequal(':'), x) + 1 : findfirst(isequal('-'), x) - 1]),
            raw_output)
    end

    """
        get_instances()::Dict{String, Dict{UInt16, UInt16}}

    Returns a map/dictionary of the active images with every active container/instance id and the port
    it's running on for each image.

    output e.g:
        Dict(
            "serviceA" => Dict(
                0 => 32777,
                1 => 1178,
                2 => 64
            ),
            "serviceB" => Dict(
                3 => 4233,
                13 => 121
            )
        )
    """
    function get_instances()::Dict{String, Dict{UInt16, UInt16}}
        raw_output::Array{String} = read(`docker ps --format "{{.Image}}:{{.Names}}@{{.Ports}}" --filter "name=$CONTAINER_SERVICE_SUFFIX"`, String) |> split
        isempty(raw_output) && return Dict()
        map(x -> replace(x, CONTAINER_REPOSITORY_PREFIX => ""), raw_output)
        out_map::Dict{String, Dict{UInt16, UInt16}} = Dict()
        for instance in raw_output
            img_name = instance[findfirst(isequal('/'), instance) + 1 : findfirst(isequal(':'), instance) - 1] 
            container_id = parse(UInt16,
                                 replace(instance[findfirst(isequal(':'),
                                                            instance) + 1 : findfirst(isequal('@'),
                                                                                      instance) - 1],
                                         img_name => ""))
            container_port = parse(UInt16,
                                   replace(instance[findfirst(isequal('@'),
                                                              instance) + 1 : findfirst(isequal('-'),
                                                                                       instance) - 1],
                                           "0.0.0.0:" => ""))
            try
                out_map[img_name][container_id] = container_port
            catch
                out_map[img_name] = Dict(container_id => container_port)
            end
        end
        out_map
    end

    """
        run_instance(image::String)::UInt16

    Launch an image container instance on a port number satisfying the down-stated conditions:
        - Either a Registered port [1024, 49151] or one from the dynamic remainder of the ports [49152, 65535]
        - Not an active port
        - Randomly selected

    One way to achieve this is by affecting the new instance port to 0, which dynamically asks the kernel
    to assign it to a free port. The function checks the existence of the image then checks the existence of
    already active instances of that image to increment the identifier of the new container's name.
    """
    function run_instance(image::String)::UInt16
        run(`docker system prune -f`)
        img_longname::String = CONTAINER_REPOSITORY_PREFIX * image
        (image ∉ get_images()) && error("Docker image requested not found!")
        
        running_containers = read(`docker ps -f ancestor=$img_longname --format "{{.Names}}"`, String) |> split
        newcontainer_name::String = ""
        if isempty(running_containers)
            newcontainer_name = image * '0'
        else
            running_ids = map(x -> parse(UInt16,
                                         replace(x, image => "")
                                        ),
                              running_containers
                             ) |> sort
            newcontainer_name = image * string(running_ids[end] + 1)
        end
        process = run(`docker run --name $newcontainer_name -d -p 0:8080 $img_longname`)
        process.exitcode
    end

    """
        kill_instance(container::String)::UInt16

    Kills the instance/container passed as an argument for this function.
    """
    function kill_instance(container::String)::UInt16
        running_containers::Array{String} = read(`docker ps --format "{{.Names}}"`, String) |> split
        (container ∉ running_containers) && error("Docker container requested not running!")
        process = run(`docker kill $container`)
        process.exitcode
    end

    """
        kill_img(img::String)::UInt16

    Kills all instances/containers hosting the image passed as an argument for this function.
    """
    function kill_img(img::String)::UInt16
        running_containers_ids::Array{UInt16} = get_instances()[img] |> keys |> collect
        isempty(running_containers_ids) && error("Docker image not hosted by any container!")
        exit_code = 0
        for id in running_containers_ids
            exit_code += kill_instance(img * string(id))
        end
        exit_code
    end

end
