# Event Booking Platform — Project Documentation

End-to-end documentation covering the platform's architecture, components,
local development setup, deployment, and the full HTTP API for every service.

---

## 1. Project Overview

A microservices-based event booking platform. Users register, browse events,
book seats with payment, and receive notifications. Organizers create and
manage events. Services communicate synchronously over HTTP and asynchronously
via RabbitMQ.

### 1.1 Repository Layout

```
cloud/
├── frontend/                 # React + Vite SPA
├── registration-service/     # Auth (register/login/JWT) + profile
├── event-service/            # Event CRUD + seat reservation
├── user-service/             # Bookings + payment verification
├── notification-service/     # Notification fan-out (RabbitMQ consumer + REST)
└── infra/                    # Compose, Kubernetes manifests, scripts, docs
    ├── compose/              # docker-compose.{yml,dev,test,prod}
    ├── kubernetes/           # Per-service manifests + base/
    ├── scripts/              # up-dev.sh, up-test.sh, up-prod.sh, k8s-*.sh
    ├── README.md
    ├── CLUSTER_SETUP.md
    ├── NETWORKING.md
    └── DOCUMENTATION.md      # (this file)
```

### 1.2 Tech Stack

| Layer            | Technology                              |
|------------------|-----------------------------------------|
| Frontend         | React 18, Vite, plain CSS               |
| Backend services | Python 3.11, FastAPI, Uvicorn, httpx    |
| Datastores       | MongoDB 6 (events, users, bookings), Redis 7 (notifications) |
| Messaging        | RabbitMQ 3.13 (topic exchange)          |
| Auth             | JWT (HS256) issued by registration-service |
| Container        | Docker, docker-compose                  |
| Orchestration    | Kubernetes (minikube for local)         |

---

## 2. Architecture

### 2.1 Service Map

```
            ┌────────────┐
            │  frontend  │  (React SPA, port 5173)
            └─────┬──────┘
                  │ HTTP
   ┌──────────────┼──────────────────────────────┐
   ▼              ▼              ▼               ▼
registration   event-       user-          notification-
  service      service      service         service
   (8000)      (8000)       (8000)            (8000)
     │            │             │                ▲
     │ JWT verify │ seat ops    │ verify token   │ consume
     └────────────┴─────────────┘                │ events.exchange
                  │                              │
                  ▼                              │
              MongoDB ◄──────── bookings ────────┤
                                                 │
                                              Redis
                                                 ▲
                                                 │ store
              RabbitMQ (events.exchange) ────────┘
```

### 2.2 Sync vs Async

- **Sync (HTTP)** — services call each other via DNS service names on port
  8000 (Docker network or Kubernetes cluster DNS). Used for token
  verification, organizer-role checks, seat reservation, profile lookups.
- **Async (RabbitMQ)** — `event-service` and others publish domain events
  (`event.created`, `event.updated`, `event.cancelled`, `booking.*`) to the
  topic exchange `events.exchange`. `notification-service` consumes them and
  persists notifications in Redis.

### 2.3 Per-Service Responsibilities

| Service                | Purpose                                           | Datastore     |
|------------------------|---------------------------------------------------|---------------|
| registration-service   | Sign-up, login, JWT issue/verify, profile         | MongoDB       |
| event-service          | Event CRUD, capacity, seat reserve/release        | MongoDB       |
| user-service           | Booking lifecycle, payment verification           | MongoDB       |
| notification-service   | Receive events + REST send/list                   | Redis         |

---

## 3. Components

### 3.1 registration-service

- Owns `users` collection in MongoDB.
- Issues JWT on login (`Authorization: Bearer <token>`).
- Exposes `/auth/profile/me` and `/auth/verify` for inter-service auth.
- Used by `event-service` to authenticate organizers and by
  `user-service` to authenticate booking actions.

Key paths: [routes.py](../registration-service/app/api/routes.py),
[main.py](../registration-service/app/main.py).

### 3.2 event-service

- Owns `events` collection.
- Public `GET` endpoints (list/detail/availability).
- Mutating endpoints require organizer role (verified via
  registration-service).
- Atomic seat reservation/release used by `user-service`.
- Publishes `event.*` events.

Key path: [routes.py](../event-service/app/api/routes.py).

### 3.3 user-service

- Owns `bookings` collection.
- Performs the booking transaction:
  verify token → check availability → verify payment → reserve seat →
  insert booking → notify attendee + organizer.
- Cancellation reverses the seat reservation and notifies both parties.

Key path: [routes.py](../user-service/app/api/routes.py).

### 3.4 notification-service

- Consumer-only on the message bus; also exposes REST endpoints for direct
  send and per-user listing.
- Notifications stored in Redis as a list per user (newest first).

Key path: [notifications.py](../notification-service/app/routes/notifications.py).

### 3.5 frontend

- React SPA in [frontend/](../frontend/).
- Dev server: `npm run dev` (default Vite port 5173).
- Auth context in [auth.jsx](../frontend/src/auth.jsx); API base in
  [api.js](../frontend/src/api.js).

---

## 4. Development Environment Setup

### 4.1 Prerequisites

- Docker Desktop (or Docker Engine + Compose v2)
- Node.js 18+ (for the frontend)
- Python 3.11+ (only if running services without containers)
- `minikube` + `kubectl` (only for the Kubernetes path)
- Git Bash or WSL on Windows for the shell scripts

### 4.2 Environment Files

Each backend service expects a `.env` file at its root. Copy
[infra/env.example](env.example) and adjust per service:

```env
MONGO_URL=mongodb://mongo:27017
RABBITMQ_URL=amqp://rabbitmq:5672
REDIS_URL=redis://redis:6379/0
JWT_SECRET=secret
SERVICE_NAME=event-service
PORT=8000
```

`SERVICE_NAME` should match the service: `registration-service`,
`event-service`, `user-service`, `notification-service`.

### 4.3 Run with Docker Compose (recommended)

From the `infra/` directory:

```bash
bash scripts/up-dev.sh    # ports 80xx, project events-dev
bash scripts/up-test.sh   # ports 81xx, project events-test
bash scripts/up-prod.sh   # ports 82xx, project events-prod

bash scripts/down-all.sh  # stop everything
```

Default dev port mapping (host → container):

| Service              | Host port | Container port |
|----------------------|-----------|----------------|
| user-service         | 8001      | 8000           |
| event-service        | 8002      | 8000           |
| registration-service | 8003      | 8000           |
| notification-service | 8004      | 8000           |
| RabbitMQ mgmt UI     | 15672     | 15672          |

### 4.4 Run the frontend

```bash
cd frontend
npm install
npm run dev
```

Point `VITE_*` env vars or [api.js](../frontend/src/api.js) at the running
backend (e.g. `http://localhost:8003` for registration).

### 4.5 Run a single service without Docker

```bash
cd event-service
python -m venv .venv && source .venv/Scripts/activate   # PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

You will need a reachable Mongo + RabbitMQ; the easiest is to start only
the infra containers:

```bash
docker compose -f infra/compose/docker-compose.yml up -d mongo rabbitmq redis
```

### 4.6 Interactive API docs

Every service exposes Swagger UI at `/docs` and ReDoc at `/redoc`, e.g.
`http://localhost:8003/docs`.

---

## 5. Deployment

### 5.1 Production Compose

```bash
bash infra/scripts/up-prod.sh
```

This runs the `compose/docker-compose.yml` + `docker-compose.prod.yml`
overlay under project name `events-prod` with restart policies, no source
mounts, and stable host ports (82xx).

### 5.2 Kubernetes (minikube)

```bash
minikube start
bash infra/scripts/k8s-build-load.sh   # build images, load into minikube
bash infra/scripts/k8s-deploy-dev.sh   # apply manifests
```

Manifests live in [infra/kubernetes/](kubernetes/):

- `namespaces/` — namespace definitions
- `mongo/`, `rabbitmq/`, `redis/` — stateful infra
- `<service>/deployment.yaml` + `service.yaml` — one folder per app
- `base/` — shared config and a service template

In-cluster service DNS pattern:
`http://<service>.<namespace>.svc.cluster.local:8000`
(see [NETWORKING.md](NETWORKING.md)).

### 5.3 Production checklist

- Replace `JWT_SECRET=secret` with a strong, secret value (use a
  Kubernetes `Secret`, not a ConfigMap).
- Enable RabbitMQ auth + TLS; replace `guest/guest`.
- Configure MongoDB auth + persistent volumes.
- Put services behind an ingress / API gateway with TLS.
- Set CORS origins on each FastAPI app to the frontend's real origin.

---

## 6. API Reference

All services listen on container port `8000`. Authenticated endpoints
expect `Authorization: Bearer <jwt>` issued by `registration-service`.

### 6.1 registration-service — `/auth`

| Method | Path                  | Auth | Description                                       |
|--------|-----------------------|------|---------------------------------------------------|
| POST   | `/auth/register`      | —    | Create a new user (`attendee` or `organizer`).    |
| POST   | `/auth/login`         | —    | Exchange credentials for a JWT.                   |
| GET    | `/auth/profile/me`    | JWT  | Return the authenticated user's profile.          |
| PUT    | `/auth/profile/me`    | JWT  | Update name / password / role-allowed fields.     |
| GET    | `/auth/verify`        | JWT  | Validate a token; returns `{ "user_id": "..." }`. |

`POST /auth/login` response:

```json
{ "access_token": "<jwt>" }
```

### 6.2 event-service — `/events`

| Method | Path                          | Auth         | Description                                    |
|--------|-------------------------------|--------------|------------------------------------------------|
| POST   | `/events`                     | organizer    | Create a new event.                            |
| GET    | `/events`                     | —            | List events. Query: `category`, `date` (ISO).  |
| GET    | `/events/{id}`                | —            | Get one event.                                 |
| PATCH  | `/events/{id}`                | organizer (owner) | Update fields.                            |
| DELETE | `/events/{id}`                | organizer (owner) | Cancel/delete.                            |
| GET    | `/events/{id}/availability`   | —            | `{ event_id, seats_left, capacity }`.          |
| POST   | `/events/{id}/reserve`        | internal     | Atomically decrement `seats_left` (409 if 0).  |
| POST   | `/events/{id}/release`        | internal     | Increment `seats_left` by 1.                   |

`POST /events` body:

```json
{
  "title": "Conf 2026",
  "description": "...",
  "category": "tech",
  "starts_at": "2026-06-01T09:00:00",
  "ends_at":   "2026-06-01T17:00:00",
  "location":  "Cairo",
  "capacity":  200
}
```

Domain events published: `event.created`, `event.updated`, `event.cancelled`.

### 6.3 user-service — bookings

| Method | Path                                | Auth | Description                                              |
|--------|-------------------------------------|------|----------------------------------------------------------|
| POST   | `/bookings`                         | JWT  | Verify payment, reserve seat, create booking, notify.    |
| GET    | `/bookings/me`                      | JWT  | List the caller's bookings.                              |
| GET    | `/bookings/{booking_id}`            | JWT  | Get one booking (owner only).                            |
| PATCH  | `/bookings/{booking_id}/cancel`     | JWT  | Cancel, release seat, refund flag, notify.               |

`POST /bookings` body:

```json
{
  "event_id":    "<event-id>",
  "card_number": "4242424242424242",
  "cvv":         "123",
  "expiry_date": "12/29"
}
```

Response:

```json
{ "message": "Booking confirmed", "booking_id": "<id>" }
```

### 6.4 notification-service — `/notifications`

| Method | Path                              | Auth | Description                                          |
|--------|-----------------------------------|------|------------------------------------------------------|
| POST   | `/notifications/send`             | —    | Persist a notification (called by other services).   |
| GET    | `/notifications/user/{user_id}`   | —    | Notification history for a user, newest first.       |
| GET    | `/notifications/health`           | —    | Liveness probe.                                      |

`POST /notifications/send` body:

```json
{
  "user_id": "<id>",
  "message": "Booking confirmed for 'Conf 2026'",
  "notification_type": "booking_confirmed",
  "event_id": "<event-id>"
}
```

The service also subscribes to `events.exchange` (RabbitMQ) and stores
notifications produced by domain events without requiring a REST call.

---

## 7. Messaging Contract

- **Exchange:** `events.exchange` (type: `topic`)
- **Routing keys:**
  - `event.created`, `event.updated`, `event.cancelled`
  - `booking.confirmed`, `booking.cancelled`
- **Payload:** JSON, always includes `event_id` and contextual fields
  (`title`, `user_id`, `changes`, …).
- **Consumers:** `notification-service` binds a queue to all `event.*`
  and `booking.*` patterns.

---

## 8. Operational Notes

- **Health:** each service has `GET /health` (or `/notifications/health`).
- **Logs:** `docker compose -p events-dev logs -f <service>` or
  `kubectl logs -n <ns> deploy/<service>`.
- **Rebuild a single image:**
  `docker compose -p events-dev -f compose/docker-compose.yml -f compose/docker-compose.dev.yml build event-service`
- **Reset volumes (data loss):**
  `docker compose -p events-dev down -v`
- **Common pitfalls:**
  - Forgetting `.env` in a service folder → container exits on import.
  - Using `localhost` from inside a container — use the service DNS name.
  - Mismatched `JWT_SECRET` between services → 401s on cross-service calls.

---

## 9. Further Reading

- [README.md](README.md) — quickstart commands
- [CLUSTER_SETUP.md](CLUSTER_SETUP.md) — minikube bootstrap
- [NETWORKING.md](NETWORKING.md) — Docker vs Kubernetes service URLs
- [kubernetes/base/DEPLOYMENT_GUIDE.md](kubernetes/base/DEPLOYMENT_GUIDE.md) — K8s deployment guide
