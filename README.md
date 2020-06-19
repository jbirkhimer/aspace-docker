# Build the file system for archivesspace and create tenants

> Currently only one tenant (default `aspace`) is created, however the `aspace-docker-start.sh` and `aspace-docker-setup.sh` scripts can be modified to create more tenants

Start by editing `aspace-docker-start.sh` and modify/set `tenant_name`, `nodes`, and `data_dir` for db and solr data persistence

Make any Archivesspace config changes that are needed and verify everything else
`vi ./aspace-custom/config.rb`

> NOTE: The `./aspace-custom/config.rb` file is a copy of SI Archivesspace production and all passwords have been replaced with `<secret>`

Then run `./aspace-docker-start.sh build` which will download the Archivesspace release version and configure everything that is needed.

> Before starting make sure the `data_dir/solr/data` dir has `8983:8983` uid:gid set otherwise solr will fail to start correctly. 


## To start over fresh (WARNING: all data will be lost!!! Make sure you know what you are doing!)  
```
# Stop any containers that may be still running
./aspace-docker-start.sh stop

### WARNING: the following cmd will also remove all docker networks, volumes, images, and containers that are not currently in use!!! ###
docker volume prune -f && docker container prune -f && docker image prune -f && docker network prune -f

# Delete the build dir and data_dir (WARNING: all existing data will be lost!!!)
sudo rm -rf ./aspace/archivesspace ./aspace/nginx ./aspace/aspace-cluster.init ./docker-data

# rebuild everything
./aspace-docker-start.sh build
```

# Start/Stop Archivesspace Containers and Stack
`./aspace-docker-start.sh start`
`./aspace-docker-start.sh stop`


# Copying existing data from database
`mysqldump -h <host> -u <user> -p <password> --single-transaction --routines --triggers <database_name> | gzip > ~/<database_name>_db.$(date +%F.%H%M%S).sql.gz`


## from lassb-service01
`mysqldump -u root -p '<secret>' --single-transaction --triggers --routines archivesspace271 | zstd --ultra -22 -T0 > /home/birkhimerj/mySQL-archivesspace271-backup.sql.zst`


## extract the mysqldump archive file
`zstd -d mySQL-archivesspace271-backup.sql.zst`


# Load mysqldump data into db on startup

> Before starting Archivesspace containers and stack move the mysqldump to `./mysql/docker-entrypoint-initdb.d/`

`mv <path-to-mysqldump>/archivesspace271-backup.sql ./mysql/docker-entrypoint-initdb.d/`

when the database starts for the first time the mysqldump file will automatically be loaded into the database


# Useful docker commands

```
docker ps                               # list running containers
docker logs -f <container-name>         # tail the containers output/log
docker exec -it <container-name> bash   # attach to a running container (like ssh)
docker exec -it <container-name> bash -c <cmd>   # attach to a running container and run cmd
docker top <container-name>             # see processes running in the container
docker stats                            # View mem, cpu, i/o, etc for running containers
docker network inspect aspace_net       # view the ip's of containers on the aspace_net network
docker --help                           # help!
```
