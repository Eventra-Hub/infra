#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

for svc in user-service event-service registration-service notification-service; do
  docker build -t "$svc:dev" "$ROOT/$svc"
done
