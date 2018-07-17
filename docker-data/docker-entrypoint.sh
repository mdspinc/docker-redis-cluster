#!/bin/sh


if [ "$1" = 'redis-cluster' ]; then
    # Allow passing in cluster IP by argument or environmental variable
    IP="${2:-$IP}"

    max_port=19007
    if [ "$CLUSTER_ONLY" = "true" ]; then
      max_port=19005
    fi

    for port in `seq 19000 $max_port`; do
      mkdir -p /redis-conf/${port}
      mkdir -p /redis-data/${port}

      if [ -e /redis-data/${port}/nodes.conf ]; then
        rm /redis-data/${port}/nodes.conf
      fi

      if [ "$port" -lt "19006" ]; then
        PORT=${port} envsubst < /redis-conf/redis-cluster.tmpl > /redis-conf/${port}/redis.conf
      else
        PORT=${port} envsubst < /redis-conf/redis.tmpl > /redis-conf/${port}/redis.conf
      fi
    done

    bash /generate-supervisor-conf.sh $max_port > /etc/supervisor/supervisord.conf

    supervisord -c /etc/supervisor/supervisord.conf
    sleep 3

    # If IP is unset then discover it
    if [ -z "$IP" ]; then
        IP=`ifconfig | grep "inet addr:17" | cut -f2 -d ":" | cut -f1 -d " "`
    fi
    echo "yes" | ruby /redis/src/redis-trib.rb create --replicas 1 ${IP}:19000 ${IP}:19001 ${IP}:19002 ${IP}:19003 ${IP}:19004 ${IP}:19005
    tail -f /var/log/supervisor/redis*.log
else
  exec "$@"
fi
