# Infra

## Services
- user-service          (HTTP)
- event-service         (HTTP)
- registration-service  (HTTP; calls user/event over HTTP; publishes to RabbitMQ)
- notification-service  (consumer-only; subscribes to events.exchange)
- mongo, rabbitmq

## Communication
- Sync: HTTP between services on port 8000 via container/service DNS name
  (e.g. http://event-service:8000)
- Async: RabbitMQ topic exchange `events.exchange`
  Publishers: user/event/registration. Consumer: notification.

## Run all 3 environments locally

```
bash scripts/up-dev.sh    # ports 80xx, project events-dev
bash scripts/up-test.sh   # ports 81xx, project events-test
bash scripts/up-prod.sh   # ports 82xx, project events-prod
```

Tear down: `bash scripts/down-all.sh`

## Kubernetes (minikube)

```
minikube start
bash scripts/k8s-build-load.sh
bash scripts/k8s-deploy-dev.sh
```
