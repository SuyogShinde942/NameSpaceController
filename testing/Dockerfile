# Build Stage
FROM golang:1.25 AS builder

WORKDIR /src

# Copy go mod files first (better caching)
# COPY go.mod go.sum ./
COPY testing/go.mod testing/go.sum ./
RUN go mod download

# Copy full source
COPY . .

ARG TARGETOS
ARG TARGETARCH

# Build linux binary
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o actions ./testing/actions.go

# Runtime Stage
FROM ubuntu:22.04

WORKDIR /nsController

COPY --from=builder /src/actions ./actions

RUN chmod +x ./actions

ENTRYPOINT ["./actions"]
