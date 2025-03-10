# DigiByte CKPool Docker Setup

This repository provides a convenient Docker setup combining DigiByte Core, ckpool, PostgreSQL, and the ckstats monitoring dashboard. It includes Docker Compose configuration for quick deployment and easy scalability.

## Features

- Builds and runs DigiByte Core (x86_64 or ARM64).
- Compiles and runs ckpool from source.
- Persistent storage for DigiByte blockchain data.
- PostgreSQL database integration for statistics and monitoring.
- Web-based monitoring dashboard (ckstats), accessible via `localhost:3000`.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [File Structure](#file-structure)
- [Docker Compose Services](#docker-compose-services)
  - [digibyte-ckpool](#digibyte-ckpool)
  - [PostgreSQL](#postgresql)
  - [ckstats Dashboard](#ckstats-dashboard)
- [Setup & Run](#build--run)
- [Accessing ckstats Dashboard](#accessing-the-ckstats-dashboard)
- [Troubleshooting](#common-issues)
- [Support & Donations](#support--donations)
- [License](#license)

## Prerequisites

- Docker & Docker Compose installed.
- At least 200GB available disk space (for blockchain data).

## File Structure

```plaintext
.
├── ckpool/             # ckpool Docker build context
├── ckstats/            # ckstats dashboard Docker build context
├── db/                 # PostgreSQL setup
│   ├── data/           # Persistent database data
│   └── init-user-db.sh # Initialization script for database
├── docker-compose.yml
├── entrypoint.sh       # Container entrypoint script
└── README.md           # This documentation
```

## Docker Compose Services

### digibyte-ckpool
- **DigiByte Core** node and **ckpool** mining pool integrated.
- Configurable via environment variables in `docker-compose.yml`.
- Persistent blockchain data in `./ckpool/data`.

### PostgreSQL
- Database service for storing ckstats monitoring data.
- Uses default database credentials:
  - User: `ckstats`
  - Password: `ckstats`
  - Database: `ckstats`
- Exposes port `5432`.

### ckstats Dashboard
- Web-based monitoring dashboard.
- Accessible at `http://localhost:3000`.
- Depends on PostgreSQL database.

## Docker Compose Configuration

Here's the complete Docker Compose file for deployment:

```yaml
services:
  digibyte-ckpool:
    build:
      context: ckpool/
      args:
        TARGETARCH: amd64
    container_name: digibyte-ckpool
    environment:
      TESTNET: "0"
      ALGO: "sha256d"
      DAEMON: "1"
      SERVER: "1"
      TXINDEX: "0"
      MAXCONNECTIONS: "300"
      DISABLEWALLET: "0"
      RPCALLOWIP: "0.0.0.0/0"
      PORT: "8433"
      RPCPORT: "8432"
      RPCBIND: "0.0.0.0"
      RPCUSER: "rpcuser"
      RPCPASSWORD: "rpcpassword"
      ONLYNET: "IPv4"
      ZMQPUBHASHBLOCK: "tcp://127.0.0.1:28435"
      DATADIR: "/home/cna.digibyte/mainnet"

      BTCD_URL: "127.0.0.1:8432"
      BTCD_AUTH: "rpcuser"
      BTCD_PASS: "rpcpassword"
      SERVERURL: "0.0.0.0:3333"
      BTCADDRESS: "dgb1qpju3lje2rjtv8h5cxje3xlv3r3004y3s60uvag"
      BTCSIG: "/mined by Casraw/"
      BLOCKPOLL: "50"
      DONATION: "0.0"
      NONCE1LENGTH: "4"
      NONCE2LENGTH: "8"
      UPDATE_INTERVAL: "5"
      VERSION_MASK: "1fffe000"
      MINDIFF: "512"
      STARTDIFF: "10000"
      LOGDIR: "/logs"
      ZMQBLOCK: "tcp://127.0.0.1:28435"

    volumes:
      - ./ckpool/data:/home/cna.digibyte/mainnet

    ports:
      - "8433:8433"
      - "8432:8432"
      - "3333:3333"
      - "4028:4028"
      - "3001:80"

  db:
    image: postgres:13
    container_name: db
    environment:
      POSTGRES_USER: ckstats
      POSTGRES_PASSWORD: ckstats
      POSTGRES_DB: ckstats
    volumes:
      - ./db/data:/var/lib/postgresql/data
      - ./db/init-user-db.sh:/docker-entrypoint-initdb.d/init-user-db.sh
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ckstats -t 20 && psql -U ckstats -d dbshadow -c 'SELECT 1' >/dev/null 2>&1"]
      interval: 20s
      timeout: 30s
      retries: 5

  ckstats:
    build:
      context: ckstats/
      dockerfile: Dockerfile
      args:
        TARGETARCH: amd64
    container_name: ckstats
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: "postgres://ckstats:ckstats@db/ckstats"
      SHADOW_DATABASE_URL: "postgres://ckstats:ckstats@db/dbshadow"
      API_URL: "http://digibyte-ckpool:4028"
      RPCUSER: "rpcuser"
      RPCPASSWORD: "rpcpassword"
      RPCPORT: "8432"
    ports:
      - "3000:3000"
```

## Build & Run

Clone this repository and launch all services:

```bash
docker-compose up --build
```

## Verify DigiByte Node

Check the node's status:

```bash
docker exec -it digibyte-ckpool digibyte-cli -conf=/etc/digibyte/digibyte.conf getblockchaininfo
```

## Common Issues

- **Error Code -28 (Loading Blocks...)**: Wait until DigiByte finishes syncing.
- **RPC connection issues:** Wait for node initialization.

## Donations & Support

- **DigiByte Address:** `dgb1qpju3lje2rjtv8h5cxje3xlv3r3004y3s60uvag`
- **GitHub:** [Casraw](https://github.com/Casraw/)

Feel free to donate if this setup helps you!

## License

Licensed under the [MIT License](https://opensource.org/licenses/MIT).
Refer to DigiByte and ckpool licenses for their specific terms.