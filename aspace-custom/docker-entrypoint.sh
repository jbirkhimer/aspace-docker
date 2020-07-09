#!/bin/bash

function setup_database {
    # Wait until MySQL is up
    while ! mysqladmin ping -h"aspace-db" -P"3306" --silent; do
        echo "Waiting for aspace-db to be ready..."
        sleep 1
    done

#    ls /aspace/archivesspace/tenants/ | egrep -v '^_template$' | while read tenant; do

        if [ ! -f /aspace/archivesspace/tenants/$tenant/database-ready ]; then
            echo "running /aspace/archivesspace/tenants/$tenant/archivesspace/scripts/setup-database.sh"

            /aspace/archivesspace/tenants/$tenant/archivesspace/scripts/setup-database.sh

            if [[ "$?" != 0 ]]; then
              echo "Error running the database setup script."
              exit 1
            else
                touch /aspace/archivesspace/tenants/$tenant/database-ready
                chown aspace:aspace /aspace/archivesspace/tenants/$tenant/database-ready
            fi
        else
            while [ ! -f /aspace/archivesspace/tenants/$tenant/database-ready ]; do
                echo "waiting for database-setup..."
            done
        fi

#    done
}


function config_loadbalancer {
    tenant_name=$1
    port_multiplier=$2
    echo "Configure loadbalancer for \"$tenant_name\" tenant"

    CONF=/aspace/nginx/conf/tenants/$tenant_name.conf

    if [ ! -f $CONF ]; then
        echo "ERROR: $CONF does not exist"
    else
        if ! grep -q `hostname` /aspace/nginx/conf/tenants/$tenant_name.conf ; then
            echo "adding tenant node: `hostname` to $(basename $CONF)"

            staff_server=`hostname`:$((8080+(100*$port_multiplier)))
            echo "adding staff_servers: $staff_server to $(basename $CONF)"
            sed -i "/^upstream ${tenant_name}staff.*/a\ server $staff_server;" $CONF

            public_server=`hostname`:$((8081+(100*$port_multiplier)))
            echo "adding public_servers: $public_server to $(basename $CONF)"
            sed -i "/^upstream ${tenant_name}public.*/a\ server $public_server;" $CONF

            echo "Finished configuring loadbalancer for \"$tenant_name\" tenant"
        fi
    fi
}

#Define cleanup procedure
cleanup() {
    echo "Container stopped!!! Cleaning up docker container instance configuration..."
    ls /aspace/archivesspace/tenants/ | egrep -v '^_template$' | while read tenant; do
        echo "removing /aspace/archivesspace/tenants/$tenant/archivesspace/config/instance_`hostname`.rb"
        rm -rf /aspace/archivesspace/tenants/$tenant/archivesspace/config/instance_`hostname`.rb
    done

    ls /aspace/nginx/conf/tenants | egrep -v '^_template.*$' | while read tenant; do
        echo "removing server `hostname` from /aspace/nginx/conf/tenants/$tenant"
        sed -i "/`hostname`/d" aspace/nginx/conf/tenants/$tenant
    done
}


case "$1" in
    start)
        port_multiplier=0
        ls /aspace/archivesspace/tenants/ | egrep -v '^_template$' | while read tenant; do

            echo "init tenant $(basename $tenant)"

            cd /aspace/archivesspace/tenants/$tenant/archivesspace

            #cd /aspace/archivesspace/tenants/$tenant/archivesspace && ./init_tenant.sh stable

            if [ -d "./version" ]; then
                mkdir -p /aspace.local/tenants/$tenant/{logs,data}
            else
                ./init_tenant.sh stable
            fi

            if [ ! -f config/instance_`hostname`.rb ]; then
                cp /aspace/archivesspace/tenants/_template/archivesspace/config/instance_hostname.rb.example config/instance_`hostname`.rb
                sed -i "s/yourhostname/`hostname`/g" config/instance_`hostname`.rb

                awk -F ":" -v OFS=":" '/backend_url/{$NF=$NF+(100*'$port_multiplier')"\","} 1' config/instance_`hostname`.rb | \
                awk -F ":" -v OFS=":" '/frontend_url/{$NF=$NF+(100*'$port_multiplier')"\","} 1' | \
                awk -F ":" -v OFS=":" '/solr_url/{$NF=$NF+(100*'$port_multiplier')"\","} 1' | \
                awk -F ":" -v OFS=":" '/indexer_url/{$NF=$NF+(100*'$port_multiplier')"\","} 1' | \
                awk -F ":" -v OFS=":" '/public_url/{$NF=$NF+(100*'$port_multiplier')"\","} 1' > tmp_`hostname` && mv tmp_`hostname` config/instance_`hostname`.rb

                oai_port=$((8082+(100*$port_multiplier)))
                sed -i "/.*public_url.*/a\  :oai_url => \"http://`hostname`:$oai_port\"," config/instance_`hostname`.rb
            fi

            setup_database
            config_loadbalancer $tenant $port_multiplier

            let "port_multiplier++"

        done

        chown -R aspace:aspace /aspace/archivesspace/tenants

        /aspace/aspace-cluster.init start
#        /aspace/aspace-cluster.init start-tenant aspace

        #Trap SIGTERM
        trap 'true' SIGTERM

        while read tenant; do
            tail -F /aspace.local/tenants/$tenant/logs/archivesspace.out >> /aspace.local/tenants/combined_archivesspace.log &
        done < <(ls /aspace.local/tenants/ )

        tail -F /aspace.local/tenants/combined_archivesspace.log

        cleanup
        ;;
    stop)
        /aspace/aspace-cluster.init stop
        ;;
    setup_database)
        setup_database
        ;;
    *)
        cat <<EOF
Usage:

  $0 start -- start tenants
  $0 stop -- stop tenants
  $0 init_tenant -- init_tenant, setup database, run <cmd>
EOF

esac