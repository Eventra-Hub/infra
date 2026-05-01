#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
docker compose -p events-prod \
  -f compose/docker-compose.yml \
  -f compose/docker-compose.prod.yml \
  up -d --build
