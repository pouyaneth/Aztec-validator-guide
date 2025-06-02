# Aztec Validator Node Setup Guide

A comprehensive guide for setting up, configuring, and maintaining an Aztec validator node on the Sepolia testnet.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
  - [RPC Setup](#rpc-setup)
  - [Service Configuration](#service-configuration)
- [Launching the Node](#launching-the-node)
- [Validator Registration](#validator-registration)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Updates](#updates)
- [Useful Commands](#useful-commands)

## Prerequisites

### System Requirements

- OS: Ubuntu 22.04 LTS or later
- CPU: 4 cores
- RAM: 8GB minimum, 16GB recommended
- Storage: 100GB SSD
- Network: Stable connection with 25+ Mbps up/down
- Ports: 40400 (TCP/UDP) and 8080 (TCP) need to be open

### Software Requirements

- Docker
- Docker Compose
- Node.js v18+
- Screen or Systemd

## Installation

1. Install required packages:

```bash
sudo apt update
sudo apt install -y curl wget jq build-essential git lz4 tmux htop libgbm1 pkg-config libssl-dev libleveldb-dev
```

2. Install Docker:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group (optional)
sudo usermod -aG docker $USER
```

3. Install Aztec CLI:

```bash
# Install Aztec CLI
npm install -g @aztec/cli

# Update to latest alpha-testnet version
aztec-up alpha-testnet
```

## Configuration

### RPC Setup

For maximum reliability, configure multiple RPC endpoints. You'll need:

- Execution RPCs (for Ethereum L1 access)
- Consensus/Beacon RPCs (for blob data)

#### Recommended Providers

- **QuickNode**: Paid service with reliable endpoints
- **Alchemy**: Offers free tier with good performance
- **Public RPCs**: Use as fallbacks

#### Setting Up RPC Endpoints

Create accounts and set up endpoints from multiple providers:

**QuickNode:**
- Create an account at quicknode.com
- Create a Sepolia endpoint with Archive data access
- Enable blob transaction support (EIP-4844)

**Alchemy:**
- Create an account at alchemy.com
- Create a Sepolia endpoint

**Public RPC Endpoints:**
- Sepolia: https://rpc.sepolia.org
- Beacon: https://sepolia-beacon.publicnode.com

### Service Configuration

Create a systemd service for reliable operation:

1. Create the service file:

```bash
sudo nano /etc/systemd/system/aztec-node.service
```

2. Add the following content (replace placeholder values with your actual endpoints):

```ini
[Unit]
Description=Aztec Node Service
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
RestartSec=30
ExecStartPre=-/usr/bin/docker stop aztec-node
ExecStartPre=-/usr/bin/docker rm aztec-node
ExecStart=/usr/bin/docker run --name aztec-node \
  --network host \
  -e ETHEREUM_HOSTS="https://your-quicknode-endpoint-1,https://your-quicknode-endpoint-2,https://your-alchemy-endpoint-1,https://your-alchemy-endpoint-2" \
  -e L1_CONSENSUS_HOST_URLS="https://your-beacon-endpoint-1,https://your-beacon-endpoint-2" \
  -e VALIDATOR_PRIVATE_KEY="0xYourPrivateKey" \
  -e COINBASE="0xYourValidatorAddress" \
  -e P2P_IP="YourPublicIPAddress" \
  -e P2P_MAX_TX_POOL_SIZE="1000000000" \
  -e LOG_LEVEL="debug" \
  -e NODE_OPTIONS="--dns-result-order=ipv4first --no-warnings --max-http-header-size=16384" \
  -e NODE_FETCH_TIMEOUT="120000" \
  -e DNS_SERVERS="1.1.1.1,8.8.8.8" \
  -v /root/.aztec:/root/.aztec \
  --dns 1.1.1.1 \
  --dns 8.8.8.8 \
  aztecprotocol/aztec:alpha-testnet \
  node --no-warnings --dns-result-order=ipv4first /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer

[Install]
WantedBy=multi-user.target
```

3. Enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable aztec-node
```

## Launching the Node

1. Start the node:

```bash
sudo systemctl start aztec-node
```

2. Check the status:

```bash
sudo systemctl status aztec-node
```

3. View the logs:

```bash
journalctl -u aztec-node -f
```

## Validator Registration

Once your node is synced, register as a validator:

```bash
aztec add-l1-validator \
--l1-rpc-urls YOUR_EXECUTION_RPC_URL \
--private-key 0xYourPrivateKey \
--attester 0xYourValidatorAddress \
--proposer-eoa 0xYourValidatorAddress \
--staking-asset-handler 0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2 \
--l1-chain-id 11155111
```

Replace the placeholder values with your actual information.

You can verify your registration status by checking your transaction on Sepolia Etherscan.

## Monitoring

### Status Check Script

Create a script to quickly check your node's status:

```bash
cat > /root/check_aztec.sh << 'EOL'
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
EOL

chmod +x /root/check_aztec.sh
```

Run with:

```bash
/root/check_aztec.sh
```

### Continuous Monitoring Script

For ongoing monitoring:

```bash
cat > /root/monitor_aztec.sh << 'EOL'
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
EOL

chmod +x /root/monitor_aztec.sh
nohup /root/monitor_aztec.sh > /dev/null 2>&1 &
```

## Troubleshooting

### Common Issues and Solutions

#### Connection Timeout Errors

If you see `TypeError: fetch failed` or `ConnectTimeoutError` errors:

1. Check your RPC endpoint connections:
```bash
curl -v YOUR_RPC_ENDPOINT
```

2. Verify your network connectivity:
```bash
ping -c 4 google.com
```

3. Make sure DNS resolution is working:
```bash
dig aztec.network
```

#### Node Not Syncing

If your node isn't syncing properly:

1. Check if you're connected to peers:
```bash
curl -s -X POST -H 'Content-Type: application/json' \
-d '{"jsonrpc":"2.0","method":"p2p_getPeers","params":[],"id":1}' \
http://localhost:8080 | jq
```

2. Ensure your RPC endpoints are working:
```bash
curl -s -X POST -H 'Content-Type: application/json' \
-d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
YOUR_RPC_ENDPOINT
```

3. Check for firewall issues:
```bash
sudo iptables -L
```

#### API Not Responding

If the API doesn't respond:

1. Check if the Docker container is running:
```bash
docker ps | grep aztec
```

2. Verify the API server is listening:
```bash
netstat -tuln | grep 8080
```

3. Restart the service:
```bash
sudo systemctl restart aztec-node
```

### Understanding Error Messages

Most common log messages and what they mean:

- **"P2P connection errors"**: Normal network communication issues, not critical
- **"Cannot propose block"**: Normal, means another validator is the current proposer
- **"Transitioning from X to Y"**: Normal validator state transitions
- **"Penalizing peer"**: Normal peer quality control mechanism
- **"Error piping data"**: Network glitches, normal in P2P systems

## Updates

When the Aztec team announces updates:

1. Stop your node:
```bash
sudo systemctl stop aztec-node
```

2. Update the Aztec CLI:
```bash
aztec-up alpha-testnet
```

3. Start your node again:
```bash
sudo systemctl start aztec-node
```

4. Verify it's working properly:
```bash
/root/check_aztec.sh
```

## Useful Commands

### Node Management

```bash
# Start the node
sudo systemctl start aztec-node

# Stop the node
sudo systemctl stop aztec-node

# Restart the node
sudo systemctl restart aztec-node

# Check status
sudo systemctl status aztec-node
```

### Logs and Monitoring

```bash
# View real-time logs
journalctl -u aztec-node -f

# View recent logs
journalctl -u aztec-node --since "1 hour ago"

# Search for errors
journalctl -u aztec-node | grep -i error
```

### API Queries

```bash
# Get current block info
curl -s -X POST -H 'Content-Type: application/json' \
-d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
http://localhost:8080 | jq

# Get connected peers
curl -s -X POST -H 'Content-Type: application/json' \
-d '{"jsonrpc":"2.0","method":"p2p_getPeers","params":[],"id":1}' \
http://localhost:8080 | jq
```

### Docker Commands

```bash
# Check running containers
docker ps

# View container logs
docker logs aztec-node

# Check resource usage
docker stats aztec-node
```

## Contributing

Feel free to submit issues or pull requests to improve this guide.

## License

MIT
