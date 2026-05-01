# infra — what this repo does

This repo does **not** hold business logic. It only orchestrates the four services + Mongo + RabbitMQ across three environments and on Kubernetes.

## What lives here
- `compose/docker-compose.yml` — base: all 4 services, mongo, rabbit, healthchecks, volumes, network.
- `compose/docker-compose.{dev,test,prod}.yml` — per-env overrides (port ranges, restart policy).
- `kubernetes/base/shared-config.yaml` — single ConfigMap + Secret consumed by every service.
- `kubernetes/<service>/` — Deployment + Service per microservice.
- `kubernetes/{mongo,rabbitmq}/` — stateful infra with PVCs.
- `kubernetes/namespaces/` — `dev`, `staging`, `prod`.
- `scripts/up-{dev,test,prod}.sh`, `down-all.sh` — compose lifecycle.
- `scripts/k8s-build-load.sh`, `k8s-deploy-dev.sh` — k8s lifecycle.

## Communication contract that infra enforces
- **Sync HTTP** between services on container DNS, port 8000:
  - `http://user-service:8000`
  - `http://event-service:8000`
  - `http://registration-service:8000`
  - `http://notification-service:8000` (no public routes — health only)
- **Async** via RabbitMQ topic exchange `events.exchange` (durable). Routing keys follow `<domain>.<entity>.<action>`:
  - `user.registered`, `user.profile.updated`, `user.profile.deleted`
  - `event.created`, `event.updated`, `event.cancelled`
  - `registration.created`, `registration.cancelled`
- **Single JWT** — `JWT_SECRET` is shared via env (compose) or k8s Secret. registration-service issues; everyone else verifies.
- **Mongo** — one instance, one DB per service: `user_db`, `event_db`, `registration_db` (and `notification_db` if you add it).

## Spin everything up (Docker)
```
bash scripts/up-dev.sh     # ports 80xx — project events-dev
bash scripts/up-test.sh    # ports 81xx — project events-test
bash scripts/up-prod.sh    # ports 82xx — project events-prod
```
All three can run **simultaneously**. Tear down with `bash scripts/down-all.sh`.

Service URLs in dev:
| Service               | URL                              |
|-----------------------|----------------------------------|
| user-service          | http://localhost:8001            |
| event-service         | http://localhost:8002            |
| registration-service  | http://localhost:8003            |
| notification-service  | http://localhost:8004            |
| RabbitMQ UI           | http://localhost:15672 (guest/guest) |
| Mongo                 | mongodb://localhost:27017        |

## Spin everything up (Kubernetes)
```
minikube start
bash scripts/k8s-build-load.sh    # build & load all 4 images into minikube
bash scripts/k8s-deploy-dev.sh    # apply namespace, shared-config, mongo, rabbit, all services
kubectl -n dev get pods -w
kubectl -n dev port-forward svc/registration-service 8003:8000   # test from host
```

## When does each service repo need this repo?
**Always.** No service runs alone — they all need Mongo + RabbitMQ + the JWT secret + each other's DNS names. From a service repo:
1. `cd ../infra && bash scripts/up-dev.sh` once, to build images and start the full stack.
2. Iterate on code.
3. Rebuild that one service: `docker compose -p events-dev -f compose/docker-compose.yml -f compose/docker-compose.dev.yml up -d --build <service-name>`.

(See each service's `WORK.md` for "Option B" host-mode dev with `uvicorn --reload`.)

## When to edit infra
Edit infra when:
- A service adds a new env var → update base compose + ConfigMap/Secret.
- A new service is added → new compose entry + new k8s folder.
- Ports change → update per-env compose overrides.
- A new RabbitMQ exchange/queue is needed → declare it in the owning service's startup; document the routing key here.

## Definition of done for infra
- `bash scripts/up-dev.sh` brings all 6 containers to Healthy.
- `curl localhost:800{1,2,3,4}/healthz` all return 200.
- `events.exchange` is visible in RabbitMQ UI.
- All three compose envs can run in parallel without port collisions.
- `kubectl -n dev get pods` shows all pods Ready.
