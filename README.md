# Build the file system
edit `aspace-docker-start.sh` modify set `tenant_name` and `nodes`

`sudo rm -rf ./aspace/archivesspace ./aspace/nginx ./aspace/aspace-cluster.init && ./aspace-docker-start.sh build`

#Start/Stop Containers
./aspace-docker-start.sh start
./aspace-docker-start.sh stop
