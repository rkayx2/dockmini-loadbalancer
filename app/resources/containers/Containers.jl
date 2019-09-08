module Containers

    using SearchLight
    using DockerCLI

    export Container

    mutable struct Container <: AbstractModel
      ### INTERNALS
      _table_name::String
      _id::String

      ### FIELDS
      id::DbId
      image::String
      instance::Integer
      port::Integer
      requests::Integer

      ### constructor
      Container(;
        ### FIELDS
        id = DbId(),
        image = "",
        instance = 0,
        port = 0,
        requests = 0
      ) = new("containers", "id",  ### INTERNALS
              id, image, instance, port, requests
             )
    end
    
    """
        seed()

    When launched, this function seeds the SQLite with already running containers
    by checking the Docker CLI app output. This is useful to do whenever the load
    balancer crashes so by that it won't at least loses track of which containers
    are running .
    """
    function seed()
        seeds::Array{Container} = []
        docker_output::Dict{String, Dict{UInt16, UInt16}} = DockerCLI.get_instances()
        for (_image, instances) in docker_output
            for (_instance, _port) in instances
                Container(image = _image,
                          instance = _instance,
                          port = _port,
                          requests = 0
                         ) |> SearchLight.save
            end
        end
    end

end
