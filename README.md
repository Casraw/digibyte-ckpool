# DigiByte + CKPool Docker Setup

This repository contains a Docker-based setup that installs **DigiByte Core** and **ckpool** in a single container. It will:

1. Download, install, and run **DigiByte Core** (either x86_64 or ARM64 build).  
2. Compile **ckpool** from source.  
3. Merge both configurations (DigiByte Core & ckpool) via environment variables from `docker-compose.yml`.  
4. Provide a persistent volume to store the DigiByte blockchain data.

**Note on Storage:**  
- The DigiByte blockchain is **approximately 35.5 GB** in size (this can grow over time).  
- The Docker image built by this repository is roughly **886.98 MB** in size.  
These numbers may vary depending on your configuration and future blockchain growth.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [File Structure](#file-structure)
- [Configuration Overview](#configuration-overview)
  - [DigiByte Core](#digibyte-core)
  - [CKPool](#ckpool)
  - [Important Note on Naming](#important-note-on-naming)
- [Usage](#usage)
  - [Build and Run](#build-and-run)
  - [Verifying DigiByte](#verifying-digibyte)
  - [Common Issues](#common-issues)
    - [Error Code -28 (Loading Blocks...)](#error-code--28-loading-blocks)
    - [Select Timed Out in read_socket_line / Failed to getblocktemplate](#select-timed-out-in-read_socket_line--failed-to-getblocktemplate)
- [Support & Donations](#support--donations)
- [License](#license)

---

## Prerequisites

- **Docker** and **Docker Compose** installed on your system.
- Sufficient disk space (at least 40GB+ to accommodate the DigiByte blockchain plus some overhead).

---

## File Structure

Within this repository, you will find:

```
.
├── Dockerfile        # Docker build instructions
├── entrypoint.sh     # Container startup script
├── docker-compose.yml
└── README.md         # This file
```

You will also want to create a local directory (e.g., `data/`) which is mounted as a volume for the DigiByte data.

---

## Configuration Overview

### DigiByte Core

By default, the container:

- Runs on `mainnet`.
- Uses the `sha256d` mining algorithm.
- Exposes ports `8433` (p2p) and `8432` (RPC).
- Keeps a persistent data directory mounted at `/home/cna.digibyte/mainnet`.

Configuration values for DigiByte are set in `docker-compose.yml` as environment variables and written to `/etc/digibyte/digibyte.conf` at container startup.

### CKPool

- It polls the local DigiByte node via `127.0.0.1:8432`.
- A single config file `/etc/ckpool/digibyte.json` is generated at startup.
- Exposes port `3333` for mining connections (defined in `docker-compose.yml`).

All parameters (e.g., `serverurl`, `btcaddress`, `zmqblock`) can be adjusted in `docker-compose.yml`.

#### Important Note on Naming

The ckpool code references some variables (like `btcaddress` and `btcsig`) because it was originally created for Bitcoin. However, in this Docker setup for DigiByte:

- **`btcaddress`** must actually be a **DigiByte address**, since it specifies where mined rewards go.  
- **`btcsig`** can be any custom tag or signature string (e.g., `/mined by me/`) and will appear in coinbase transaction data.

---

## Usage

### Build and Run

1. **Clone** this repository or copy the files into a new directory.
2. **Create a subdirectory** named `data` (or whichever name you use in the volume config) to store DigiByte blockchain data.
3. **Edit environment variables** in `docker-compose.yml` to match your desired settings:
   - `RPCUSER`, `RPCPASSWORD`, `BTCD_PASS`, **`BTCADDRESS`** (which should be your DigiByte address), etc.
4. **Run**:

   ```bash
   docker-compose up --build
   ```

   This will:
   - Build the image.
   - Start the DigiByte daemon in the background.
   - Start `ckpool` in the foreground.

### Verifying DigiByte

Once running, you can verify that DigiByte is running correctly by opening a new terminal and checking:

```bash
docker exec -it digibyte-ckpool bash
digibyte-cli -conf=/etc/digibyte/digibyte.conf getblockchaininfo
```

If you see blockchain info in JSON form, DigiByte is running fine.

---

## Common Issues

### Error Code -28 (Loading Blocks...)

If you see something like:

```
error code: -28
error message:
Loading blocks... 50%
```

This is **not** a critical failure. It means DigiByte is still starting up and loading its blockchain data. It **temporarily** can’t serve the `getblocktemplate` or other RPC calls. Simply wait for the node to finish loading (the percentage should reach 100%), and ckpool will be able to connect successfully.

### Select Timed Out in read_socket_line / Failed to getblocktemplate

If you see log entries like:

```
[2025-03-08 10:29:29.025] Failed to read socket line in _json_rpc_call ("getblock...") 66.675s
[2025-03-08 10:29:29.025] 127.0.0.1:8432 Failed to get valid json response to getblocktemplate
[2025-03-08 10:30:35.730] Select timed out in read_socket_line with errno 11: Resource temporarily unavailable
```

That often means DigiByte is **busy** performing initial operations (such as indexing blocks) and is **slow** to respond to ckpool’s RPC calls. If the node is under heavy load (during syncing, reindexing, etc.), ckpool may periodically fail its `getblocktemplate` calls.

**Solution**: You generally just need to **wait**. Once DigiByte finishes the initial indexing or syncing, it will respond more quickly to RPC calls. ckpool will then fetch new block templates successfully. If you want to reduce these timeouts or wait for DigiByte to be fully loaded before starting ckpool, you can add a **wait loop** in your `entrypoint.sh` so ckpool only starts once DigiByte is actually responsive.

---

## Support & Donations

- **Docker Setup by Casraw**  
  - DigiByte Address: `dgb1qpju3lje2rjtv8h5cxje3xlv3r3004y3s60uvag`  
  - GitHub: [Casraw](https://github.com/Casraw/)

- **Original CKPool Setup by Mecanix**  
  - DigiByte Address: `dgb1qk2n9m3mpjka2ym7s9jcergznyz7fpzh5wy2hj3`

If you find this setup helpful, feel free to send a tip!

---

## License

This project is released under the [MIT License](https://opensource.org/licenses/MIT).  
Refer to upstream DigiByte and ckpool licenses for their respective terms.