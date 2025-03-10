#!/usr/bin/env bash

# Set the default entrypoint to be the ckstats binary
set +e

export FNM_PATH="/root/.local/share/fnm"
export PATH="$FNM_PATH:$PATH"
eval "`fnm env --use-on-cd`"

# create the .env file
cat <<EOF > /app/ckstats/.env
# The following are substituted from environment vars in docker-compose:
DATABASE_URL=${DATABASE_URL}
SHADOW_DATABASE_URL=${SHADOW_DATABASE_URL}
API_URL=${API_URL}
EOF

# Start the cron service
service cron start

while true; do
# Attempt to call getblockchaininfo
  OUTPUT=$(digibyte-cli -rpcconnect=digibyte-ckpool -rpcport=$RPCPORT -rpcuser=$RPCUSER -rpcpassword=$RPCPASSWORD getblockchaininfo 2>&1)
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

set -e
# migrate the database
cd /app/ckstats
#pnpm prisma:migrate
# seed the database
#pnpm seed
# build the app
pnpm build
# start the server
pnpm start