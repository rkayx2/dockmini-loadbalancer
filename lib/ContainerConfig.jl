module ContainerConfig
    """Services images to be managed by the load balancer service would have to follow some rules:
            - Containers images' names have to be prefixed by the same user repository name
            that would be specified in the 'CONTAINER_REPOSITORY_PREFIX' constant.
            
            - Containers images' names have to be suffixed by the same string, usually that is used
            to specify the usecase/need/service that all the managed containers are serving. The suffix
            is specifid in the 'CONTAINER_SERVICE_SUFFIX' constant.
            
            - For each instance/container running for a service, there's a limit/threshold of subscribed
            requests to fulfill. It has to be specified down here in the 'CONTAINER_REQUEST_LIMIT' constant.

       The load balancer front control is serving as a web service so a host and a port have to be specified.
       This is done using the 'LOADBALANCER_HOST', 'LOADBALANCER_PORT' constants.
    """

    const CONTAINER_REPOSITORY_PREFIX = "reputationaire/"
    const CONTAINER_SERVICE_SUFFIX = "rank"
    const CONTAINER_REQUEST_LIMIT = 500
    const LOADBALANCER_HOST = "127.0.0.1"
    const LOADBALANCER_PORT = 8002

    export CONTAINER_REPOSITORY_PREFIX, CONTAINER_REQUEST_LIMIT,
           CONTAINER_SERVICE_SUFFIX, LOADBALANCER_HOST, LOADBALANCER_PORT
end
