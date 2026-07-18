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

**Frontend**
```bash
cd frontend
npm install
npm start
```

**Backend**
```bash
cd backend
go run main.go
```
Set these environment variables locally (see `k8s/deployment.yaml` for the production equivalents):
- `REDIS_HOST`
- `MONGO_URI`

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

## Health check

The backend exposes `GET /api/v1/health` for readiness/liveness probes and the ALB target group health check.

## Kubernetes notes

- `deployment.yaml` uses `RollingUpdate` with `maxSurge: 1, maxUnavailable: 0` — zero-downtime deploys
- `service.yaml` exposes `NodePort 30080`, matching the port the Terraform-managed ALB (in `starttech-infra`) targets
- `ingress.yaml` is optional — only needed if you're using the AWS Load Balancer Controller instead of the Terraform-managed ALB; don't run both at once
