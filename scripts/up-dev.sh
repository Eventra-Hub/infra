#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
docker compose -p events-dev \
  -f compose/docker-compose.yml \
  -f compose/docker-compose.dev.yml \
  up -d --build
