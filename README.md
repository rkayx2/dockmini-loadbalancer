## Controlled Dockerized Images Load Balancer - rank_loadbalancer

A Dockerized transactional based (request/tx subscription & delayed response fetch) services load balancer with a frontend restful API using Genie framework.

## Getting Started

The project can be seperated in 2 chunks based on the use case:

-   Load balancing system using SQLite as a registry for container control event and requests load tracking

-   'Restfully' wrapped-frontend for containers control

For now, as it's on a hurry, it's simply incrementing the not-fetched-requests number for each free/available-to-serve container instance entry in its database each time a request subscription is done until the instance achieves its request threshold then it runs a new instance. For each request subscription it assigns the least not-fetched-requests container port to serve. The load balance algorithm will be tweaked and optimized each late update for the proejct.

### Prerequisites

Mainly, this project uses only a few libraries & dependencies:

- Docker Engine (.io)

-   Docker CLI

-   Julia v1.0 or above

-   Genie.jl (The Genie web framework)

-   SearrchLight.jl (The SearchLight ORM)

### Installing

A step by step series of examples that tell you how to get a development env running

- Install Julia language & Docker Engine & Docker CLI on the desktop (v1.0 or above):

        sudo apt update

        sudo apt remove docker docker docker-engine docker.io

        sudo apt -y install build-essential docker.io

        sudo systemctl start docker

        sudo systemctl enable docker

        wget https://julialang-s3.julialang.org/bin/linux/x64/1.0/julia-1.0.4-linux-x86_64.tar.gz

        tar xvfz julia-1.0.4-linux-x86_64.tar.gz

        sudo ln -s $HOME/julia-1.0.4/bin/julia /usr/local/bin/julia 

- Install all requirements from the deps.jl file:

        julia deps.jl

## Running the tests

- To run the interactive/dev environment of the app:

        bin/repl

    or

        julia> cd("[APP_DIRECTORY]")

        julia> ]

        (v1.0.4) pkg> activate .

        (rank_loadbalancer) pkg> (Backspace)

        julia> using Genie

        julia> Genie.loadapp()

        julia> Genie.startup()

- Open a web browser and call "http://127.0.0.1:8002/api" to get your controlled containers status response:

    For every endpoint triggered, the response is designed as always having a "status" attribute giving an idea about the state of the response or the request treatment state:

        SUCCESS:                Successful request

        MISSING_FIELD_VALUE:    Request does not specify a value for a mandatory field
        
        UNKNOWN_FIELD_VALUE:    Request specified an unknown value by the backend for one of its fields
        
        INVALID_FIELD_LENGTH:   Request specified a (< min) || (> max) length value for one of its fields
        
        DUPLICATE_FIELD_VALUE:  Request violated UNIQUE constraint of some entries in the backend

        INTERNAL_SERVER_ERROR:  Something went wrong in the backend, see logs for more details

        BAD_REQUEST_FORMAT:     Request does not respect its format, check the documentaion or the source code for more information

        BAD_FIELD_FORMAT:       Request specified value for one of its fields does not comply with a particular format

- Launch an endpoint call from within an API Dev Environment (e.g Postman) or a browser:

        GET - localhost:8002/api            Status of all running controlled containers

        POST - localhost:8002/api           Fetch available ports for all services array passed within

        POST - localhost:8002/api/done      Free all specified ports from 1 request

- For control & administration purpose, other endpoints are available (May be used within a control/administration dashboard for the load balancer), To be used cautiously:

        GET - localhost:8002/api/kill?instance=<INSTANCE_NAME>                      Kills the specified instance if running

        GET - localhost:8002/api/kill?image=<IMAGE_NAME>                            Kills all running instances of the specified image

        GET - localhost:8002/api/run?image=<IMAGE_NAME>                             Runs an instance of the specified image

        GET - localhost:8002/api/run?image=<IMAGE_NAME>&nbr=<INSTANCES_NUMBER>      Runs INSTANCES_NUMBER instances of the specified image

        GET - localhost:8002/api/images                                             Fetches all available images of controlled containers

        GET - localhost:8002/api/images?running=<yes || no || true || false>        Fetches all images of controlled containers with the specified state

        GET - localhost:8002/api/ports                                              Fetches all occupied ports by controlled containers

### Break down into results

The output is a JSON response always containing a "status" attribute with the response's state code. It also may contain a "body" attribute holding the response of the endpoint if ever a response is needed (in GET - api/images, GET - api/ports, GET/POST - api/)

- GET - localhost:8002/api

        body:{
            serv1_inst:{
                0:  37543,
                1:  23245
            },
            serv2_inst:{
                5:  21344
            }
        },
        status: "SUCCESS"

    If "body" attribute is empty, that means that no instance of the controlled containers is running.

    For this up stated response, this means that 2 instances of serv1_inst image are running, which are serv1_inst0 on port:37543 and serv1_inst1 on port:23245, and only 1 instance of serv2_inst, called serv2_inst5, is running on port:21344

- POST - localhost:8002/api
    
    Request Body (This is to request a free port for each of serv1_inst and serv2_inst images/containers)

        services:[
            "serv1_inst", "serv2_inst", "serv3_falsename"
        ]

    Response
        
        body:{
            serv1_inst: 37543,
            serv2_inst: 21344,
            serv3_falsename: 0
        },
        status: "SUCCESS"

    Here, in the request, "serv3_falsename" is either a non-existant controlled image, or a mistakenly spelled image name, so the service demander has to handle this error on his own.

- POST - localhost:8002/api/done

    Request Body (This is to free serv1_inst instance on 37543 port, serv2_inst instance on 21344 port, and serv3_falsename on 2323 port)

        serv1_inst: 37543,
        serv2_inst: 21344,
        serv3_falsename: 2323

    Response

        serv1_inst: "SUCCESS",
        serv2_inst: "INTERNAL_SERVER_ERROR",
        serv3_falsename: "UNKNOWN_FIELD_VALUE"

    Here, this endpoint response is the only one not holding a "body" and "status" attribute as an API design solution for the fact that it's a multiple call for many endpoints, so for each instance name is associated the response of its "request-freeing call". The serv1_inst is freed from a request count succesfully, the freeing operation of serv2_inst encountered a problem that has to be checked within the load balancer logs, and the serv3_falsename image isn't existant/running. Be Careful as if there were a serv3_falsename image in the local docker repository and no instance is running, the response will always be "UNKNOWN_FIELD_VALUE".

## Deployment

To get a deployed instance running:

- Follow the "Installation" instructions

- Either run the load balancer server by just entering

        bin/server

  Or link that command to one output/startup_file entry on your server

## Built With

* [Julia v1.1](https://julialang.org/) - The Julia Programming Language
* [Genie](https://genieframework.com/) - The highly productive Julia web framework
* [DockerCLI.jl](https://github.com/rkayx2/DockerCLI.jl) - A Docker specified images tree controlling library

## Authors

Ramy Kader - [GitHub](https://github.com/rkayx2)
