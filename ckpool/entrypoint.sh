#!/usr/bin/env bash
set +e

touch /home/cna.digibyte/mainnet/debug.log
DGB_CONF="/etc/digibyte/digibyte.conf"
DGB_LOGFILE="/home/cna.digibyte/mainnet/debug.log"

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

cat <<EOF > /etc/apache2/sites-available/users.conf
<VirtualHost *:80>
    ServerName localhost
    
    DocumentRoot /logs

    <Directory "/logs">
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted

        # Die konkrete Datei als JSON ausliefern, auch ohne .json-Endung
        <Files *>
            ForceType application/json
        </Files>
    </Directory>

    # Logfiles anpassen wie du möchtest:
    ErrorLog ${APACHE_LOG_DIR}/users_error.log
    CustomLog ${APACHE_LOG_DIR}/users_access.log combined
</VirtualHost>
EOF

# Enable the users site and disable the default site
a2dissite 000-default
a2ensite users
# Start Apache
service apache2 start
# Reload Apache
service apache2 reload

echo "Starting DigiByte daemon..."
digibyted -conf="$DGB_CONF" &
DGB_PID=$!

echo "DigiByte started with PID=$DGB_PID"
echo "Waiting for DigiByte to become ready (initial block download may take time)..."

while true; do
  # 1) Check if digibyted is still running
  #    kill -0 returns 0 if the process is alive, and non-zero if not.
  kill -0 "$DGB_PID" 2>/dev/null
  KILL_EXIT_CODE=$?

  if [ $KILL_EXIT_CODE -ne 0 ]; then
    # Here, kill -0 returned a code other than 0, which typically means
    # "No such process" or "permission denied" (rare in a Docker container).
    #
    # In most cases, it means digibyted has exited or crashed.
    # We'll confirm by checking if the process name is still visible via pgrep.

    echo "kill -0 returned code $KILL_EXIT_CODE. Checking if digibyted still exists..."

    if ! pgrep -x digibyted >/dev/null 2>&1; then
      echo "digibyted is definitely not running. Exiting with error."
      echo "Last 50 lines of debug.log:"
      tail -n 50 "$DGB_LOGFILE" || true
      exit 1
    else
      echo "Odd scenario: kill -0 says non-zero, but pgrep sees digibyted. Continuing..."
    fi
  fi

  # 2) Attempt to call getblockchaininfo
  OUTPUT=$(digibyte-cli -conf="$DGB_CONF" getblockchaininfo 2>&1)
  RPC_EXIT_CODE=$?

  if [ $RPC_EXIT_CODE -eq 0 ]; then
    # Successfully got JSON; now parse the initialblockdownload field
    IBD=$(echo "$OUTPUT" | jq -r '.initialblockdownload' 2>/dev/null)

    # If .initialblockdownload is false, it's fully synced
    if [ "$IBD" = "false" ]; then
      echo "DigiByte has finished initial block download."
      break
    else
      echo "DigiByte is still syncing. initialblockdownload=$IBD"
    fi
  else
    echo "DigiByte not ready. RPC error code $RPC_EXIT_CODE."
    echo "Output: $OUTPUT"
  fi

  echo "Sleeping 10s..."
  sleep 10
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
set -e

# Finally, start ckpool in the foreground:
echo "Starting ckpool..."
cd /ckpool/src
exec ./ckpool -B -c /etc/ckpool/digibyte.json &
CKP_PID=$!
sleep 120
chmod +rx -R /logs/
# 3) Periodically monitor both processes
#    - If DigiByte dies, kill ckpool and exit
#    - If ckpool dies, exit
while true; do
  sleep 30
  
  # a) Check if digibyted is still running
  if ! pgrep -x digibyted >/dev/null 2>&1; then
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