#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
docker compose -p events-test \
  -f compose/docker-compose.yml \
  -f compose/docker-compose.test.yml \
  up -d --build
