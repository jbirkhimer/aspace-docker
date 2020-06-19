#!/bin/bash

#set -evx

tenant_name=aspace
nodes=2
base_dir=$PWD/aspace
#version=2.6.0
#version=2.7.0
version=2.7.1
data_dir=$PWD/docker-data

function build {

    mkdir -p $base_dir/archivesspace/software/

    mkdir -p $data_dir/mysql
    mkdir -p $data_dir/solr/data
    sudo chown -R 8983:8983 $data_dir/solr/data

    cd $base_dir/archivesspace/software/

#    cp ../../../archivesspace-v$version.zip ./ \
    wget https://github.com/archivesspace/archivesspace/releases/download/v$version/archivesspace-v$version.zip \
    && unzip -x -q archivesspace-v$version.zip

    mv archivesspace archivesspace-$version

    ln -s archivesspace-$version stable

    cp -av ./stable/clustering/files/* $base_dir

    sed -i "s/FILE/__FILE__/g" $base_dir/archivesspace/config/config.rb

    cd ./stable/lib && wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.24/mysql-connector-java-5.1.24.jar

    sed -i "/RUN_AS=\"appuser\"/c\RUN_AS=\"aspace\"" $base_dir/aspace-cluster.init
    sed -i "/\.\/archivesspace\.sh start/c\    ./archivesspace.sh" $base_dir/aspace-cluster.init

    config_plugins
    config_fonts
    config_base_config
    config_tenant
    config_loadbalancer

}

function config_plugins {
    cd $base_dir
    echo "Copying custom plugins.."
    cp -r ../aspace-custom/plugins $base_dir/archivesspace/software/archivesspace-$version
}


function config_fonts {
    echo "Copying custom fonts.."
    cp -r ../aspace-custom/arial $base_dir/archivesspace/software/archivesspace-$version/reports/static/fonts
}


function config_base_config {
    echo "Copying custom config.rb"
    cat ../aspace-custom/config.rb >> $base_dir/archivesspace/config/config.rb
}


function config_tenant {
    echo "Building tenant \"$tenant_name\"..."

    cd $base_dir/archivesspace/tenants

    cp -a _template $tenant_name

    cd $base_dir/archivesspace/tenants/$tenant_name/archivesspace

#    sed -i "/db_url/c\AppConfig[:db_url] = \"jdbc:mysql://aspace-db:3306/$tenant_name$i?user=aspace&password=aspace&useUnicode=true&characterEncoding=UTF-8\"" config/config.rb
    sed -i '/db_url/c\AppConfig[:db_url] = ENV["APPCONFIG_DB_URL"]' config/config.rb

    sed -i '/search_user_secret/c\AppConfig[:search_user_secret] = ENV["search_user_secret"]' config/config.rb
    sed -i '/public_user_secret/c\AppConfig[:public_user_secret] = ENV["public_user_secret"]' config/config.rb
    sed -i '/staff_user_secret/c\AppConfig[:staff_user_secret] = ENV["staff_user_secret"]' config/config.rb
    sed -i '/frontend_cookie_secret/c\AppConfig[:frontend_cookie_secret] = ENV["frontend_cookie_secret"]' config/config.rb
    sed -i '/public_cookie_secret/c\AppConfig[:public_cookie_secret] = ENV["public_cookie_secret"]' config/config.rb

    echo "Finished building tenant \"$tenant_name\"..."
}

function config_loadbalancer {
    echo "Configure loadbalancer..."

    CONF=$base_dir/nginx/conf/tenants/$tenant_name.conf

    cp $base_dir/nginx/conf/tenants/_template.conf.example $CONF

    echo "patch $CONF..."

    sed -i 's/<tenantname>/'$tenant_name'/g' $CONF
    sed -i 's/<tenant staff hostname>/'$tenant_name'.staff.'`hostname`'/g' $CONF
    sed -i 's/<tenant public hostname>/'$tenant_name.'public.'`hostname`'/g' $CONF
    sed -i "/apps.*/d" $CONF

    for i in $(seq $nodes); do
        echo "adding node: "$tenant_name$i
        staff_servers="$staff_servers\n\tserver $tenant_name$i:8080;"
        public_servers="$public_servers\n\tserver $tenant_name$i:8081;"
    done

    echo "adding staff_servers: "$staff_servers
    tenant_name_staff=$tenant_name"staff"
    sed -i "/^upstream $tenant_name_staff.*/a\ $staff_servers" $CONF

    echo "adding public_servers: "$public_servers
    tenant_name_public=$tenant_name"public"
    sed -i "/^upstream $tenant_name_public.*/a\ $public_servers" $CONF

    echo "Finished configuring loadbalancer..."

}

function config_db {
    echo "Configure db script... $PWD"
    mkdir -p $base_dir/docker-entrypoint-initdb.d
    touch $base_dir/docker-entrypoint-initdb.d/aspace-mysql-init.sql
    for i in $(seq $nodes); do
        echo "adding db $tenant_name$i"
        echo "create database $tenant_name$i default character set utf8; grant all on $tenant_name$i.* to 'aspace'@'%' identified by 'aspace';" >> $base_dir/docker-entrypoint-initdb.d/aspace-mysql-init.sql
    done
    echo "Finished configuring db..."
}


function start_cluster {

    if [[ ! $(docker inspect --format="{{.Id}}" aspace_net 2> /dev/null) ]]; then
        echo "network not found! Creating network..."
        docker network create aspace_net
    fi


    if [[ $(docker inspect --format="{{.Id}}" aspace-db 2> /dev/null) ]]; then
        # container found.

        docker start aspace-db
    else
        # container not found.

        docker run -t -d \
        --env-file ./.env \
        --name aspace-db \
        --network aspace_net \
        -p 3307:3306 \
        -v $PWD/mysql/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
        -v $data_dir/mysql:/var/lib/mysql \
        mariadb:10.1.45 --character-set-server=utf8
    fi

    if [[ $(docker inspect --format="{{.Id}}" aspace-solr 2> /dev/null) ]]; then
        # container found.

        docker start aspace-solr
    else
        # container not found.

        docker run -t -d \
        --env-file ./.env \
        --name aspace-solr \
        --network aspace_net \
        -p 8983:8983 \
        -v $PWD/solr/archivesspace:/archivesspace \
        -v $data_dir/solr/data:/archivesspace-data/data \
        solr:6.6.1 solr-create -p 8983 -c archivesspace -d /archivesspace
    fi


    if [[ $(docker inspect --format="{{.Id}}" aspace-db-init 2> /dev/null) ]]; then
        # container found.

        docker start aspace-db-init
    else
        # container not found.

        #    docker build --no-cache -t aspace-tenant:latest ./aspace
        docker build -t aspace-tenant:latest ./aspace-custom/

        docker run -it \
        --env-file ./.env \
        -v $PWD/aspace:/aspace \
        --network aspace_net \
        --name aspace-db-init \
        aspace-tenant:latest setup_database
    fi

    for i in $(seq $nodes); do

        if [[ $(docker inspect --format="{{.Id}}" $tenant_name$i 2> /dev/null) ]]; then
            # container found.

             docker start $tenant_name$i
        else
            # container not found.

            docker run -t -d \
            --env-file ./.env \
            -v $PWD/aspace:/aspace \
            --hostname $tenant_name$i \
            --name $tenant_name$i \
            --network aspace_net \
            aspace-tenant:latest

            sleep 15
        fi

    done


    if [[ $(docker container inspect --format="{{.Id}}" aspace-loadbalancer 2> /dev/null) ]]; then
        # container found.

        docker start aspace-loadbalancer
    else
        # container not found.

        docker build -t aspace-loadbalancer:latest ./nginx

        docker run -t -d \
        --env-file ./.env \
        --name aspace-loadbalancer \
        --hostname aspace-loadbalancer \
        -p 8080:80 \
        --network aspace_net \
        -v $PWD/aspace:/aspace \
        aspace-loadbalancer:latest

#        --add-host localnode:$(ifconfig eth0 | grep inet | grep -v inet6 | awk '{print $2}') \
    fi

}

case "$1" in
    start)
        start_cluster
        ;;
    stop)
        stop_cmd="docker container stop"

        for i in $(seq $nodes); do
            stop_cmd=$stop_cmd" $tenant_name$i"
            rm -f aspace/archivesspace/tenants/$tenant_name/archivesspace/config/instance_*.rb
        done

        stop_cmd=$stop_cmd" aspace-db aspace-loadbalancer aspace-solr"
        $stop_cmd

#       docker network rm aspace_net
        rm aspace/archivesspace/tenants/database-ready
        ;;
    build)
        build
        ;;
    *)
        cat <<EOF
Usage:

  $0 start -- start ALL containers, tenants and nodes
  $0 stop -- stop ALL containers, tenants and nodes
  $0 build -- build default tenant: $tenant_name, num nodes: $nodes, solr and mysql data_dir: $data_dir
EOF

esac