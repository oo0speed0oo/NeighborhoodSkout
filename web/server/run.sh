#!/usr/bin/env bash
# Starts the NeighborhoodSkout storage server. Used by the systemd service.
cd "$(dirname "$0")"
exec python3 server.py
