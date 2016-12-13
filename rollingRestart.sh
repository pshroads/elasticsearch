#!/bin/bash

HOST=$1

ES_HEALTH_URL="http://$HOST:9200/_cat/health"

read clusterName clusterHealth relocatingShards initializingShards unassignedShards pendingTasks <<< $(curl -s $ES_HEALTH_URL | awk '{print $3 " " $4 " " $9 " " $10 " " $11 " " $12}')

if [ "$clusterHealth" != "green" ]
	then
		echo "Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks)."			
		echo "Cluster must be green to do a rolling restart. Exiting."
		exit
fi

echo "$(date +%Y-%m-%d_%H:%M:%S) - Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks)."			
read -p "Perform a rolling restart for cluster $clusterName? Y or N:" -n 2 -r

if [[ $REPLY =~ ^[Yy]$ ]]
	then
		ES_NODES_URL="http://$HOST:9200/_cat/nodes"
	    echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting rolling restart...."
	    for clusterNode in `curl -s -XGET $ES_NODES_URL | awk '{print $1}' | sort`; 
	    do
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Restarting elasticsearch service on $clusterNode"
	    	ssh $clusterNode 'sudo service elasticsearch restart'
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Checking that cluster state is green before proceeding..."
			read clusterName clusterHealth relocatingShards initializingShards unassignedShards pendingTasks <<< $(curl -s $ES_HEALTH_URL | awk '{print $3 " " $4 " " $9 " " $10 " " $11 " " $12}')
			while [ "$clusterHealth" != "green" ]
				do
					echo "$(date +%Y-%m-%d_%H:%M:%S) - Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks). Waiting for it to turn green..."
					sleep 60s
					read clusterName clusterHealth relocatingShards initializingShards unassignedShards pendingTasks <<< $(curl -s $ES_HEALTH_URL | awk '{print $3 " " $4 " " $9 " " $10 " " $11 " " $12}')
				done	
				echo "$(date +%Y-%m-%d_%H:%M:%S) - Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks).\n"
			done
fi

echo "$(date +%Y-%m-%d_%H:%M:%S) - Done."
