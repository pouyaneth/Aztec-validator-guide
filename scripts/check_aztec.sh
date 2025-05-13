#!/bin/bash

echo "===== AZTEC NODE STATUS CHECK ====="
echo

# Check service status
echo "SERVICE STATUS:"
systemctl status aztec-node | grep "Active:"
echo

# Check block info
echo "BLOCK INFORMATION:"
BLOCK_INFO=$(curl -s -X POST -H 'Content-Type: application/json' \
-d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
http://localhost:8080)

LATEST=$(echo $BLOCK_INFO | jq -r '.result.latest.number')
PROVEN=$(echo $BLOCK_INFO | jq -r '.result.proven.number')
FINALIZED=$(echo $BLOCK_INFO | jq -r '.result.finalized.number')

echo "Latest block: $LATEST"
echo "Proven block: $PROVEN"
echo "Finalized block: $FINALIZED"
echo

# Check peer connections
echo "PEER CONNECTIONS:"
PEERS=$(curl -s -X POST -H 'Content-Type: application/json' \
-d '{"jsonrpc":"2.0","method":"p2p_getPeers","params":[],"id":1}' \
http://localhost:8080 | jq -r '.result | length')
echo "Connected to $PEERS peers"
echo

# Check recent errors
echo "RECENT ERRORS (last 10 minutes):"
ERROR_COUNT=$(journalctl -u aztec-node --since "10 minutes ago" | grep -i "error" | 
              grep -v "dial failed" | 
              grep -v "error in dial queue" | 
              grep -v "error piping data through muxer" | 
              grep -v "goodbye sub protocol" | 
              grep -v "identify error" | 
              wc -l)
echo "Found $ERROR_COUNT significant errors"
echo

echo "===== STATUS CHECK COMPLETE ====="
