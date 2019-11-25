#!/bin/bash
set -euo pipefail

docker build -t haproxy-dap:latest .
