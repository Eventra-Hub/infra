#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

NS=staging
REPLICAS=2

kubectl apply -f kubernetes/namespaces/staging.yaml
kubectl -n "$NS" apply -f kubernetes/base/shared-config.yaml
kubectl -n "$NS" apply -f kubernetes/mongo/
kubectl -n "$NS" apply -f kubernetes/rabbitmq/
kubectl -n "$NS" apply -f kubernetes/redis/
kubectl -n "$NS" apply -f kubernetes/user-service/
kubectl -n "$NS" apply -f kubernetes/event-service/
kubectl -n "$NS" apply -f kubernetes/registration-service/
kubectl -n "$NS" apply -f kubernetes/notification-service/

for svc in user-service event-service registration-service notification-service; do
  kubectl -n "$NS" scale deployment "$svc" --replicas="$REPLICAS"
done
