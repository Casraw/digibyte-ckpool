#!/usr/bin/env bash
set -e

DGB_CONF="/etc/digibyte/digibyte.conf"
LOGFILE="/home/cna.digibyte/mainnet/debug.log"

# Generate DigiByte Core config from environment variables:
cat <<EOF > /etc/digibyte/digibyte.conf
# The following are substituted from environment vars in docker-compose:
testnet=${TESTNET}
algo=${ALGO}
daemon=${DAEMON}
server=${SERVER}
txindex=${TXINDEX}
maxconnections=${MAXCONNECTIONS}
disablewallet=${DISABLEWALLET}
rpcallowip=${RPCALLOWIP}
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
onlynet=${ONLYNET}
zmqpubhashblock=${ZMQPUBHASHBLOCK}

datadir=${DATADIR}
port=${PORT}
rpcport=${RPCPORT}
rpcbind=${RPCBIND}
EOF

echo "Starting DigiByte daemon..."
digibyted -conf="$DGB_CONF" &
DGB_PID=$!

# Monitor digibyted startup and runtime
while true; do
  # 1) Check if digibyted has crashed (process no longer running)
  if ! kill -0 "$DGB_PID" 2>/dev/null; then
    echo "digibyted has stopped unexpectedly. Here's the last 50 lines of the log:"
    tail -n 50 "$LOGFILE" || true
    # Exit the script so Docker sees the container fail and can restart it
    exit 1
  fi

  # 2) Check if digibyted is responding to RPC
  if digibyte-cli -conf="$DGB_CONF" getblockchaininfo >/dev/null 2>&1; then
    echo "DigiByte RPC is up and running."
    break
  else
    echo "Waiting for DigiByte RPC to become ready..."
    # Print some log lines for visibility
    tail -n 50 "$LOGFILE" || true
    sleep 5
  fi
done

# Generate ckpool config from environment variables:
cat <<EOF > /etc/ckpool/digibyte.json
{
  "btcd" : [
    {
      "url" : "${BTCD_URL}",
      "auth" : "${BTCD_AUTH}",
      "pass" : "${BTCD_PASS}"
    }
  ],
  "serverurl" : [
    "${SERVERURL}"
  ],
  "btcaddress" : "${BTCADDRESS}",
  "btcsig" : "${BTCSIG}",
  "blockpoll" : ${BLOCKPOLL},
  "donation" : ${DONATION},
  "nonce1length" : ${NONCE1LENGTH},
  "nonce2length" : ${NONCE2LENGTH},
  "update_interval" : ${UPDATE_INTERVAL},
  "version_mask" : "${VERSION_MASK}",
  "mindiff" : ${MINDIFF},
  "startdiff" : ${STARTDIFF},
  "logdir" : "${LOGDIR}",
  "zmqblock" : "${ZMQBLOCK}"
}
EOF

# Finally, start ckpool in the foreground:
echo "Starting ckpool..."
cd /ckpool/src
exec ./ckpool -B -c /etc/ckpool/digibyte.json
CKP_PID=$!

# 3) Periodically monitor both processes
#    - If DigiByte dies, kill ckpool and exit
#    - If ckpool dies, exit
while true; do
  sleep 30

  # a) Check if digibyted is still running
  if ! kill -0 "$DGB_PID" 2>/dev/null; then
    echo "digibyted process has exited unexpectedly."
    echo "Showing last 50 lines of the DigiByte log:"
    tail -n 50 "$DGB_LOGFILE" || true

    # Stop ckpool, then exit so Docker knows container failed
    kill "$CKP_PID" 2>/dev/null || true
    exit 1
  fi

  # You could optionally do an RPC check here if you want to confirm the node
  # is still responding, e.g.:
  # if ! digibyte-cli -conf="$DGB_CONF" getblockchaininfo >/dev/null 2>&1; then
  #   echo "digibyted is not responding on RPC, shutting down."
  #   kill "$CKP_PID" 2>/dev/null || true
  #   exit 1
  # fi

  # b) Check if ckpool is still running
  if ! kill -0 "$CKP_PID" 2>/dev/null; then
    echo "ckpool process has exited."
    # If ckpool dies, just exit the container so Docker can restart
    exit 1
  fi
done