#!/bin/bash

LOG_FILE="/root/aztec_monitor.log"

while true; do
  echo "$(date) - Checking node status" >> $LOG_FILE
  
  # Get current block info
  BLOCK_INFO=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
  http://localhost:8080)
  
  # Extract block numbers
  LATEST=$(echo $BLOCK_INFO | jq -r '.result.latest.number')
  PROVEN=$(echo $BLOCK_INFO | jq -r '.result.proven.number')
  
  echo "$(date) - Latest: $LATEST, Proven: $PROVEN" >> $LOG_FILE
  
  # Get peer count
  PEERS=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"p2p_getPeers","params":[],"id":1}' \
  http://localhost:8080 | jq -r '.result | length')
  
  echo "$(date) - Connected peers: $PEERS" >> $LOG_FILE
  echo "----------------------------------" >> $LOG_FILE
  
  # Sleep for an hour
  sleep 3600
done
