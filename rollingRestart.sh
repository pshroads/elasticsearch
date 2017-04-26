#!/bin/bash

HOST=$1

ESUSER=$(whoami)
read -p "Password for $ESUSER:" -s PWD
CURL_SUCCESS_RESPONSE='"acknowledged":true'

ES_HEALTH_URL="http://$HOST:9200/_cat/health"

read clusterName clusterHealth relocatingShards initializingShards unassignedShards pendingTasks <<< $(curl -u $ESUSER:$PWD   -s $ES_HEALTH_URL | awk '{print $3 " " $4 " " $9 " " $10 " " $11 " " $12}')

if [ "$clusterHealth" != "green" ] || [ "$relocatingShards" -ne "0" ] || [ "$initializingShards" -ne "0" ] || [ "$unassignedShards" -ne "0" ] || [ "$pendingTasks" -ne "0" ]
	then
		echo "Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks)."			
		echo "Cluster must be green with stable shards to do a rolling restart. Exiting."
		exit
fi

echo "$(date +%Y-%m-%d_%H:%M:%S) - Cluster state is $clusterHealth with stable shards ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks)."			
read -p "Perform a rolling restart for cluster $clusterName? Y or N:" -n 2 -r

if [[ $REPLY =~ ^[Yy]$ ]]
	then
		ES_NODES_URL="http://$HOST:9200/_cat/nodes"
	    echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting rolling restart...."
	    for clusterNode in `curl -u $ESUSER:$PWD   -s -XGET $ES_NODES_URL | awk '{print $1}' | sort`; 
	    do
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Disabling shard rebalance"
	    	CURL_RESPONSE=$(curl -u $ESUSER:$PWD   -s -XPUT "http://$HOST:9200/_cluster/settings" -d '{"transient" : {"cluster.routing.allocation.enable" : "none"}}')
	    	sleep 5s
	    	while ! [[ "$CURL_RESPONSE" =~ "$CURL_SUCCESS_RESPONSE" ]]
	    		do
	    			sleep 5s
	    			CURL_RESPONSE=$(curl -u $ESUSER:$PWD   -s -XPUT "http://$HOST:9200/_cluster/settings" -d '{"transient" : {"cluster.routing.allocation.enable" : "none"}}')
	    		done
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Restarting elasticsearch service on $clusterNode"
	    	ssh $clusterNode 'sudo service elasticsearch restart'
	    	sleep 5s
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Re-enabling shard rebalance"
	    	CURL_RESPONSE=$(curl -u $ESUSER:$PWD   -s -XPUT "http://$HOST:9200/_cluster/settings" -d '{"transient" : {"cluster.routing.allocation.enable" : "all"}}')
	    	sleep 5s
	    	while ! [[ "$CURL_RESPONSE" =~ "$CURL_SUCCESS_RESPONSE" ]]
	    		do
	    			sleep 5s
	    			CURL_RESPONSE=$(curl -u $ESUSER:$PWD   -s -XPUT "http://$HOST:9200/_cluster/settings" -d '{"transient" : {"cluster.routing.allocation.enable" : "all"}}')
	    		done
	    	echo "$(date +%Y-%m-%d_%H:%M:%S) - Checking that cluster state is green before proceeding..."
			read clusterName clusterHealth relocatingShards initializingShards unassignedShards pendingTasks <<< $(curl -u $ESUSER:$PWD   -s $ES_HEALTH_URL | awk '{print $3 " " $4 " " $9 " " $10 " " $11 " " $12}')
			while [ "$clusterHealth" != "green" ] || [ "$relocatingShards" -ne "0" ] || [ "$initializingShards" -ne "0" ] || [ "$unassignedShards" -ne "0" ] || [ "$pendingTasks" -ne "0" ]
				do
					echo "$(date +%Y-%m-%d_%H:%M:%S) - Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks). Waiting..."
					sleep 60s
					read clusterName clusterHealth relocatingShards initializingShards unassignedShards pendingTasks <<< $(curl -u $ESUSER:$PWD   -s $ES_HEALTH_URL | awk '{print $3 " " $4 " " $9 " " $10 " " $11 " " $12}')
				done	
				echo "$(date +%Y-%m-%d_%H:%M:%S) - Cluster state is $clusterHealth ($relocatingShards relocating shards, $initializingShards initializing shards, $unassignedShards unassigned shards, $pendingTasks pending tasks).\n"
		done
fi

echo "$(date +%Y-%m-%d_%H:%M:%S) - Done."
