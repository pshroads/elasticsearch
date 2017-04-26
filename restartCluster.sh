#!/bin/bash

HOST=$1 # Any node in the cluster

ES_HEALTH_URL="http://$HOST:9200/_cat/health"

ESUSER=$(whoami)
read -p "Password for $ESUSER:" -s PWD

read clusterName clusterHealth relocatingShards initializingShards unassignedShards pendingTasks <<< $(curl -u $ESUSER:$PWD -s $ES_HEALTH_URL | awk '{print $3 " " $4 " " $9 " " $10 " " $11 " " $12}')
echo "$(date +%Y-%m-%d_%H:%M:%S) - Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks)."			
echo "!!! ALL NODES WILL BE STOPPED AND RESTARTED !!!"
read -p "Restart cluster $clusterName? Y or N:" -n 2 -r

if [[ $REPLY =~ ^[Yy]$ ]]
	then
		ES_NODES_URL="http://$HOST:9200/_cat/nodes"
	    echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting cluster restart...."
	    clusterNodes=$(curl -u $ESUSER:$PWD -s -XGET $ES_NODES_URL | awk '{print $1}' | sort)
	    
	    for clusterNode in $clusterNodes
	    do
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Stopping elasticsearch service on $clusterNode"
	    	ssh $clusterNode 'sudo service elasticsearch stop'
	    done

	    for clusterNode in $clusterNodes
	    do
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting elasticsearch service on $clusterNode"
	    	ssh $clusterNode 'sudo service elasticsearch start'
	    done	    


fi

echo "$(date +%Y-%m-%d_%H:%M:%S) - Done."
