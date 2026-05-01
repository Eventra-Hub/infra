#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
for env in dev test prod; do
  docker compose -p events-$env \
    -f compose/docker-compose.yml \
    -f compose/docker-compose.$env.yml \
    down -v || true
done
