#!/bin/bash

IMAGENAME=snx-checkpoint-vpn

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPTDIR"
docker build -t "$IMAGENAME" .
