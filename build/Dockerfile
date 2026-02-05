# Build stage
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY cmd/ ./cmd/
COPY pkg/ ./pkg/

# Build the application
# The binary will be at /app/bin/controller
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/controller ./cmd/controller

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/bin/controller .

# Run the controller
CMD ["./controller"]
