#!/usr/bin/env bash
# Put a newer index.html / server.py in this folder, then run:  bash update.sh
# Your map (in the data folder) and config.env are never touched.
set -e
cd "$(dirname "$0")"
python3 -c "import ast;ast.parse(open('server.py').read())"
test -f index.html || { echo "index.html is missing here"; exit 1; }
systemctl --user restart skout
sleep 2
systemctl --user status skout --no-pager | head -5
