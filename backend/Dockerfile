# --- Build stage ---
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Cache dependency downloads separately from source changes
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server ./cmd/api

# --- Runtime stage ---
FROM alpine:3.19

RUN apk add --no-cache ca-certificates && update-ca-certificates

WORKDIR /app
COPY --from=builder /app/server .

EXPOSE 8080

ENTRYPOINT ["/app/server"]
