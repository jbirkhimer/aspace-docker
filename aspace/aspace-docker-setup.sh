#!/bin/bash

function setup_database {
    # Wait until MySQL is up
    while ! mysqladmin ping -h"db" -P"3306" --silent; do
        echo "Waiting for db to be up..."
        sleep 1
    done

    if [ ! -f /aspace/archivesspace/tenants/database-ready ]; then
        /aspace/archivesspace/software/stable/scripts/setup-database.sh

        if [[ "$?" != 0 ]]; then
          echo "Error running the database setup script."
          exit 1
        else
            touch /aspace/archivesspace/tenants/database-ready
            chown aspace:aspace /aspace/archivesspace/tenants/database-ready
        fi
    else
        echo "database setup already!"
    fi
}


case "$1" in
    start)
        ls /aspace/archivesspace/tenants/ | egrep -v '^_template$|database-ready' | while read tenant; do

            echo "init tenant $(basename $tenant)"

            cd /aspace/archivesspace/tenants/$tenant/archivesspace && ./init_tenant.sh stable

            if [ ! -f config/instance_`hostname`.rb ]; then
                cp /aspace/archivesspace/tenants/_template/archivesspace/config/instance_hostname.rb.example config/instance_`hostname`.rb
                sed -i "s/yourhostname/`hostname`/g" config/instance_`hostname`.rb
            fi

        done

        /aspace/aspace-cluster.init start
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