#!/bin/bash

#set -evx

source ./.env

base_dir=$PWD
version=$ARCHIVESSPACE_VERSION

aspace_base_dir=$(realpath $ASPACE_DATA_DIR)/aspace
data_dir=$(realpath $ASPACE_DATA_DIR)
tenant_list=$TENANT_LIST
nodes=$NODES


function build {

    mkdir -p $aspace_base_dir/archivesspace/software/

    mkdir -p $data_dir/mysql

    for tenant_name in ${tenant_list//,/ }; do
        mkdir -p $data_dir/solr/{$tenant_name}
    done
    sudo chown -R 8983:8983 $data_dir/solr

    cd $aspace_base_dir/archivesspace/software/

#    wget https://github.com/archivesspace/archivesspace/releases/download/v$version/archivesspace-v$version.zip \
    cp $base_dir/archivesspace-v$version.zip ./ \
    && unzip -x -q archivesspace-v$version.zip

    mv archivesspace archivesspace-$version

    ln -s archivesspace-$version stable

    cp -av ./stable/clustering/files/* $aspace_base_dir

    sed -i "s/FILE/__FILE__/g" $aspace_base_dir/archivesspace/config/config.rb

    cd ./stable/lib && wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.24/mysql-connector-java-5.1.24.jar

    sed -i "/.*RUN_AS=\"appuser\"/c\RUN_AS=aspace" $aspace_base_dir/aspace-cluster.init
#    sed -i "/\.\/archivesspace\.sh start/c\    ./archivesspace.sh" $aspace_base_dir/aspace-cluster.init

    config_plugins
    config_fonts
    config_base_config
    for tenant_name in ${tenant_list//,/ }; do
        config_tenant $tenant_name
        config_loadbalancer $tenant_name
        config_db $tenant_name
    done

}

function config_plugins {
    echo "Copying custom plugins.."
    cp -r $base_dir/aspace-custom/plugins $aspace_base_dir/archivesspace/software/archivesspace-$version
}


function config_fonts {
    echo "Copying custom fonts.."
    cp -r $base_dir/aspace-custom/arial $aspace_base_dir/archivesspace/software/archivesspace-$version/reports/static/fonts
}


function config_base_config {
    echo "Copying custom config.rb"
    cat $base_dir/aspace-custom/config.rb >> $aspace_base_dir/archivesspace/config/config.rb
}


function config_tenant {
    tenant_name=$1
    echo "Building tenant \"$tenant_name\""

    cd $aspace_base_dir/archivesspace/tenants

    cp -a _template $tenant_name

    cd $aspace_base_dir/archivesspace/tenants/$tenant_name/archivesspace

    sed -i "/db_url/c\AppConfig[:db_url] = \"jdbc:mysql://aspace-db:3306/$tenant_name$i?user=aspace&password=aspace&useUnicode=true&characterEncoding=UTF-8\"" config/config.rb

    sed -i "/.*db_url.*/a\AppConfig[:solr_url] = \"http://aspace-solr:8983/solr/$tenant_name\"" config/config.rb
#    sed -i "/.*db_url.*/a\AppConfig[:enable_solr] = false" config/config.rb
#    sed -i "/.*db_url.*/a\AppConfig[:enable_docs] = false" config/config.rb

    sed -i '/search_user_secret/c\AppConfig[:search_user_secret] = ENV["APPCONFIG_SEARCH_USER_SECRET"]' config/config.rb
    sed -i '/public_user_secret/c\AppConfig[:public_user_secret] = ENV["APPCONFIG_PUBLIC_USER_SECRET"]' config/config.rb
    sed -i '/staff_user_secret/c\AppConfig[:staff_user_secret] = ENV["APPCONFIG_STAFF_USER_SECRET"]' config/config.rb
    sed -i '/frontend_cookie_secret/c\AppConfig[:frontend_cookie_secret] = ENV["APPCONFIG_FRONTEND_COOKIE_SECRET"]' config/config.rb
    sed -i '/public_cookie_secret/c\AppConfig[:public_cookie_secret] = ENV["APPCONFIG_PUBLIC_COOKIE_SECRET"]' config/config.rb

    sed -i "/.*public_cookie_secret.*/a\AppConfig[:indexer_log] = proc { File.join(File.expand_path(File.dirname(__FILE__)), \"../logs/indexer_$tenant_name.log\") }" config/config.rb
    sed -i "/.*public_cookie_secret.*/a\AppConfig[:pui_log] = proc { File.join(File.expand_path(File.dirname(__FILE__)), \"../logs/pui_$tenant_name.log\") }" config/config.rb
    sed -i "/.*public_cookie_secret.*/a\AppConfig[:frontend_log] = proc { File.join(File.expand_path(File.dirname(__FILE__)), \"../logs/frontend_$tenant_name.log\") }" config/config.rb
    sed -i "/.*public_cookie_secret.*/a\AppConfig[:backend_log] = proc { File.join(File.expand_path(File.dirname(__FILE__)), \"../logs/backend_$tenant_name.log\") }" config/config.rb

    sed -i '/.*indexer_log.*/a\AppConfig[:public_proxy_url] = "http://'$tenant_name.public'.'`hostname`'"' config/config.rb
    sed -i '/.*indexer_log.*/a\AppConfig[:frontend_proxy_url] = "http://'$tenant_name'.staff.'`hostname`'"' config/config.rb


    echo "Finished building tenant \"$tenant_name\""
}

function config_loadbalancer {
    echo "Configure loadbalancer..."

    CONF=$aspace_base_dir/nginx/conf/tenants/$tenant_name.conf

    cp $aspace_base_dir/nginx/conf/tenants/_template.conf.example $CONF

    echo "patch $CONF"

    sed -i 's/<tenantname>/'$tenant_name'/g' $CONF
    sed -i 's/<tenant staff hostname>/'$tenant_name'.staff.'`hostname`'/g' $CONF
    sed -i 's/<tenant public hostname>/'$tenant_name.'public.'`hostname`'/g' $CONF
    sed -i "/apps.*/d" $CONF

    echo "Finished configuring loadbalancer..."

}

function config_db {
    echo "Configure db init for for \"$tenant_name\""
    echo "adding db $tenant_name"
    echo "create database if not exists $tenant_name default character set utf8; grant all on $tenant_name.* to 'aspace'@'%' identified by 'aspace';" >> $base_dir/mysql/docker-entrypoint-initdb.d/_init_db.sql
    echo "grant all on $tenant_name.* to 'bowmang'@'%.si.edu' identified by 'aspace';" >> $base_dir/mysql/docker-entrypoint-initdb.d/_init_db.sql

    if [[ "$(ls $base_dir/mysql/docker-entrypoint-initdb.d/ | egrep $tenant_name)" == *"$tenant_name"* ]]; then
        dumpfile=$(ls $base_dir/mysql/docker-entrypoint-initdb.d/ | egrep $tenant_name)
        echo "$tenant_name using dumpfile = $dumpfile"
        if [[ $(head -n 1 $base_dir/mysql/docker-entrypoint-initdb.d/$dumpfile) == *"use $tenant_name"* ]]; then
            echo "$dumpfile already contains \"use $tenant_name;\""
        else
            echo "adding \"use $(basename $tenant_name .sql);\" to $dumpfile"
            sed -i "1 i\use $tenant_name;\n" $base_dir/mysql/docker-entrypoint-initdb.d/$dumpfile
        fi
    else
        dumpfile=$(ls $base_dir/mysql/docker-entrypoint-initdb.d/ | egrep $tenant_name)
        echo "ERROR: dumpfile not found for \"$tenant_name\" tenant!!! Make sure the dump file is located in \"$base_dir/mysql/docker-entrypoint-initdb.d/\" and the filename contains \"$tenant_name\" ( ex. ${tenant_name}_mysql_dump.sql )!!!"
    fi
    echo "Finished configuring db for \"$tenant_name\""
}


#function docker_run {
#
#    if [[ ! $(docker inspect --format="{{.Id}}" aspace_net 2> /dev/null) ]]; then
#        echo "network not found! Creating network"
#        docker network create aspace_net
#    fi
#
#
#    if [[ $(docker inspect --format="{{.Id}}" aspace-db 2> /dev/null) ]]; then
#        # container found.
#
#        docker start aspace-db
#    else
#        # container not found.
#
#        docker run -t -d \
#        --env-file ./.env \
#        --name aspace-db \
#        --network aspace_net \
#        -p 3307:3306 \
#        -v $PWD/mysql/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
#        -v $data_dir/mysql:/var/lib/mysql \
#        mariadb:10.1.45 --character-set-server=utf8
#    fi
#
#    if [[ $(docker inspect --format="{{.Id}}" aspace-solr 2> /dev/null) ]]; then
#        # container found.
#
#        docker start aspace-solr
#    else
#        # container not found.
#
#        docker run -t -d \
#        --env-file ./.env \
#        --name aspace-solr \
#        --network aspace_net \
#        -p 8983:8983 \
#        -v $PWD/solr/archivesspace:/archivesspace \
#        -v $data_dir/solr/data:/archivesspace-data/data \
#        solr:6.6.1 solr-create -p 8983 -c archivesspace -d /archivesspace
#    fi
#
#
#    if [[ $(docker inspect --format="{{.Id}}" aspace-db-init 2> /dev/null) ]]; then
#        # container found.
#
#        docker start aspace-db-init
#    else
#        # container not found.
#
#        #    docker build --no-cache -t aspace-tenant:latest ./aspace
#        docker build -t aspace-tenant:latest ./aspace-custom/
#
#        docker run -it \
#        --env-file ./.env \
#        -v $aspace_base_dir:/aspace \
#        --network aspace_net \
#        --name aspace-db-init \
#        aspace-tenant:latest setup_database
#    fi
#
#    for i in $(seq $nodes); do
#
#        if [[ $(docker inspect --format="{{.Id}}" $tenant_name$i 2> /dev/null) ]]; then
#            # container found.
#
#             docker start $tenant_name$i
#        else
#            # container not found.
#
#            docker run -t -d \
#            --env-file ./.env \
#            -v $aspace_base_dir:/aspace \
#            --hostname $tenant_name$i \
#            --name $tenant_name$i \
#            --network aspace_net \
#            aspace-tenant:latest
#
#            sleep 15
#        fi
#
#    done
#
#
#    if [[ $(docker container inspect --format="{{.Id}}" aspace-loadbalancer 2> /dev/null) ]]; then
#        # container found.
#
#        docker start aspace-loadbalancer
#    else
#        # container not found.
#
#        docker build -t aspace-loadbalancer:latest ./nginx
#
#        docker run -t -d \
#        --env-file ./.env \
#        --name aspace-loadbalancer \
#        --hostname aspace-loadbalancer \
#        -p 8080:80 \
#        --network aspace_net \
#        -v $aspace_base_dir:/aspace \
#        aspace-loadbalancer:latest
#
##        --add-host localnode:$(ifconfig eth0 | grep inet | grep -v inet6 | awk '{print $2}') \
#    fi
#
#}
#
#
#function docker_run_stop {
#    stop_cmd="docker container stop"
#
#    for i in $(seq $nodes); do
#        stop_cmd=$stop_cmd" $tenant_name$i"
#        rm -f $aspace_base_dir/archivesspace/tenants/$tenant_name/archivesspace/config/instance_*.rb
#        rm -f $aspace_base_dir/archivesspace/tenants/$tenant_name/database-ready
#    done
#
#    stop_cmd=$stop_cmd" aspace-db aspace-loadbalancer aspace-solr"
#    $stop_cmd
#
#    #docker network rm aspace_net
#}

function start_cluster {
    echo "Starting Archivesspace with $nodes nodes"

    # clean up any existing container configurations
    for tenant_name in ${tenant_list//,/ }; do
        rm -rf $aspace_base_dir/archivesspace/tenants/$tenant_name/archivesspace/config/instance_*.rb

        sed -i "/^upstream ${tenant_name}staff/,/\}/{//!d}"  $aspace_base_dir/nginx/conf/tenants/${tenant_name}.conf
        sed -i "/^upstream ${tenant_name}public/,/\}/{//!d}"  $aspace_base_dir/nginx/conf/tenants/${tenant_name}.conf
    done

#    docker-compose up -d --scale aspace=$nodes

    if [ "$nodes" -eq 1 ]; then
        docker-compose --compatibility up -d
    else
        # start nodes one by one
        echo "Starting aspace stack with a single node first..."
        docker-compose --compatibility up -d --scale aspace-loadbalancer=0
        scale
    fi

}

function scale {
    echo "Scaling up to $nodes nodes..."
        for i in $(seq $nodes); do
            if [ "$i" -eq "$nodes" ]; then
                echo "Starting last node $i and loadbalancer..."
                sleep 30
                docker-compose --compatibility up -d --scale aspace=$i --no-recreate aspace aspace-db aspace-solr aspace-loadbalancer
            else
                if [ "$i" -gt 1 ]; then
                    echo "Starting addition node $i..."
                    sleep 30
                    docker-compose --compatibility up -d --scale aspace=$i --scale aspace-loadbalancer=0 --no-recreate aspace aspace-db aspace-solr
                fi
            fi

        done
}

function reload_loadbalancer_config {
    # restart nginx container when upstream servers is updated
    docker exec -it aspace-loadbalancer nginx -s reload
}


function add_tenant {
    echo "Adding tenant: $1"
#    config_tenant $1
#    config_loadbalancer $1
#    config_db $1
}

case "$1" in
    start)
        shift
        if [ -z "$1" ]; then
            nodes=1
        else
            nodes=$1
        fi

        start_cluster
        ;;
    stop)
        docker-compose --compatibility down
        ;;
    build)
        shift
        build $@
        ;;
    add_tenant)
        shift
        add_tenant $@
        ;;
     scale)
        shift
        if [ -z "$1" ]; then
            echo "ERROR: must provide number of nodes to scale up to i.e. $0 scale <#nodes>"
        else
            nodes=$1
            scale
            reload_loadbalancer_config
        fi
        ;;
    *)
        cat <<EOF
Usage:

  $0 start -- start ALL containers, tenants and nodes
  $0 stop -- stop ALL containers, tenants and nodes
  $0 build -- build default tenant(s): $tenant_list; num nodes: $nodes; solr and mysql data_dir: $data_dir
EOF

esac