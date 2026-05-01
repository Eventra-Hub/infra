#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

NS=dev

kubectl apply -f kubernetes/namespaces/dev.yaml
kubectl -n "$NS" apply -f kubernetes/base/shared-config.yaml
kubectl -n "$NS" apply -f kubernetes/mongo/
kubectl -n "$NS" apply -f kubernetes/rabbitmq/
kubectl -n "$NS" apply -f kubernetes/user-service/
kubectl -n "$NS" apply -f kubernetes/event-service/
kubectl -n "$NS" apply -f kubernetes/registration-service/
kubectl -n "$NS" apply -f kubernetes/notification-service/
