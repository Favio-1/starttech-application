# starttech-application

Application source and delivery pipeline for the StartTech assessment: React frontend, Golang backend API, Kubernetes manifests, and CI/CD workflows.

## Structure

```
frontend/          # React source (from much-to-do, feature/full-stack branch)
backend/            # Golang REST API + Dockerfile
k8s/                # Kubernetes manifests (deployment, service, ingress)
scripts/            # Deploy, health-check, rollback helpers
.github/workflows/  # frontend-ci-cd.yml, backend-ci-cd.yml
```

## Prerequisites

- Node.js 20+, npm
- Go 1.22+
- Docker
- AWS CLI, configured
- kubectl

## Local development

**Frontend** (Vite + React + TypeScript)
```bash
cd frontend
npm install
npm run dev
```

**Backend** (Go, Gin) — entry point is `cmd/api/main.go`
```bash
cd backend
go run ./cmd/api
```
Copy `.env.example` to `.env` in `backend/` and fill in real values. Key variables the app actually reads (see `internal/config`):
- `PORT` (defaults to 8080)
- `MONGO_URI`, `DB_NAME`
- `JWT_SECRET_KEY`, `JWT_EXPIRATION_HOURS`
- `ENABLE_CACHE`, `REDIS_ADDR` (host:port, e.g. `localhost:6379` — **not** `REDIS_HOST`)
- `ALLOWED_ORIGINS` (comma-separated, for CORS)

Real backend routes have **no `/api` prefix**: `/health`, `/auth/*`, `/tasks/*`, `/users/*`. In production, CloudFront's `/api/*` rule forwards to the ALB and a CloudFront Function strips the `/api` prefix before it reaches the app — see `starttech-infra/terraform/modules/cdn/main.tf`.

## Deploying manually

```bash
./scripts/deploy-frontend.sh <s3-bucket-name> <cloudfront-distribution-id>
./scripts/deploy-backend.sh <ecr-repository-url> <eks-cluster-name>
./scripts/health-check.sh https://<cloudfront-domain>
```

To roll back a bad backend deploy:
```bash
./scripts/rollback.sh <eks-cluster-name>
```

## CI/CD

Two workflows, triggered by path:
- **frontend-ci-cd.yml** — on changes to `frontend/`: install → audit → build → sync to S3 → invalidate CloudFront
- **backend-ci-cd.yml** — on changes to `backend/` or `k8s/`: test → build → Trivy scan → push to ECR → apply k8s manifests → verify rollout

### Required repository secrets

| Secret | Used by |
|---|---|
| `AWS_ACCESS_KEY_ID` | both workflows |
| `AWS_SECRET_ACCESS_KEY` | both workflows |
| `FRONTEND_BUCKET_NAME` | frontend-ci-cd.yml |
| `CLOUDFRONT_DISTRIBUTION_ID` | frontend-ci-cd.yml |

These values come from the `starttech-infra` repo's Terraform outputs (`terraform output frontend_bucket_id`, `terraform output cloudfront_distribution_id`, etc).

### Kubernetes secret (manual, one-time)

`deployment.yaml` reads Mongo/Redis/JWT config from a Secret named `backend-secrets`, which is **not** created by CI (secrets in git are a bad idea). Copy `k8s/secret.yaml.example` to `k8s/secret.yaml`, fill in real values, and apply once:
```bash
kubectl apply -f k8s/secret.yaml
```

## Health check

The backend exposes `GET /health` (no `/api` prefix — see note above) for readiness/liveness probes and the ALB target group health check. Through CloudFront, reach it at `/api/health`.

## Kubernetes notes

- `deployment.yaml` uses `RollingUpdate` with `maxSurge: 1, maxUnavailable: 0` — zero-downtime deploys
- `service.yaml` exposes `NodePort 30080`, matching the port the Terraform-managed ALB (in `starttech-infra`) targets
- `ingress.yaml` is optional — only needed if you're using the AWS Load Balancer Controller instead of the Terraform-managed ALB; don't run both at once
