#!/bin/bash
set -euo pipefail

# =============================================================================
# Gratitude App — EC2 Bootstrap (run via SSM or SSH on the EC2)
# =============================================================================
# Installs Docker, PostgreSQL (via Docker), certbot, and creates the env file.
#
# Usage (via SSM from your local machine):
#   aws ssm start-session --target i-07eab9fcba8e4457a
#   # then paste this script, OR:
#   aws ssm send-command --instance-ids i-07eab9fcba8e4457a \
#     --document-name AWS-RunShellScript \
#     --parameters commands="$(cat scripts/setup-ec2.sh | jq -Rs .)"
# =============================================================================

EC2_INSTANCE_ID="i-07eab9fcba8e4457a"
AWS_REGION="us-west-2"
DOMAIN="gratitude.davidjbarnes.com"

echo "=== Gratitude EC2 Bootstrap ==="

# --- Docker ---
echo "[1/5] Installing Docker..."
if command -v docker &>/dev/null; then
  echo "  Docker already installed"
else
  dnf install -y docker || yum install -y docker || apt-get install -y docker.io
  systemctl enable docker
  systemctl start docker
fi

# --- Docker Compose plugin ---
echo "[2/5] Installing Docker Compose..."
if docker compose version &>/dev/null; then
  echo "  Docker Compose already installed"
else
  DOCKER_CONFIG=${DOCKER_CONFIG:-/usr/local/lib/docker}
  mkdir -p "$DOCKER_CONFIG/cli-plugins"
  ARCH=$(uname -m)
  curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
  chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
fi

# --- Environment file ---
echo "[3/5] Creating environment file..."
mkdir -p /opt/gratitude

if [ ! -f /opt/gratitude/.env ]; then
  JWT_SECRET=$(openssl rand -hex 32)
  PG_PASSWORD=$(openssl rand -hex 16)

  cat > /opt/gratitude/.env <<ENV
DATABASE_URL=postgresql+asyncpg://gratitude:${PG_PASSWORD}@localhost:5432/gratitude
JWT_SECRET=${JWT_SECRET}
CORS_ORIGINS=https://${DOMAIN}
ENV

  # Store PG password separately for docker-compose
  echo "POSTGRES_PASSWORD=${PG_PASSWORD}" > /opt/gratitude/postgres.env

  echo "  Created /opt/gratitude/.env (JWT_SECRET and PG_PASSWORD generated)"
else
  echo "  /opt/gratitude/.env already exists, skipping"
fi

# --- PostgreSQL via Docker ---
echo "[4/5] Starting PostgreSQL..."
source /opt/gratitude/postgres.env 2>/dev/null || true

if docker ps --format '{{.Names}}' | grep -q '^gratitude-postgres$'; then
  echo "  PostgreSQL container already running"
else
  docker stop gratitude-postgres 2>/dev/null || true
  docker rm gratitude-postgres 2>/dev/null || true

  docker run -d \
    --name gratitude-postgres \
    --restart unless-stopped \
    -e POSTGRES_DB=gratitude \
    -e POSTGRES_USER=gratitude \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    -p 127.0.0.1:5432:5432 \
    -v gratitude-pgdata:/var/lib/postgresql/data \
    postgres:16-alpine

  echo "  PostgreSQL started on port 5432"

  # Wait for postgres to be ready
  for i in $(seq 1 30); do
    if docker exec gratitude-postgres pg_isready -U gratitude &>/dev/null; then
      echo "  PostgreSQL is ready"
      break
    fi
    sleep 1
  done
fi

# --- SSL Certificate ---
echo "[5/5] Setting up SSL certificate..."
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
  echo "  SSL certificate already exists for ${DOMAIN}"
else
  if command -v certbot &>/dev/null; then
    echo "  certbot found"
  else
    pip3 install certbot || dnf install -y certbot || yum install -y certbot || apt-get install -y certbot
  fi

  echo "  Requesting certificate for ${DOMAIN}..."
  echo "  NOTE: Port 80 must be open and DNS must point to this server"
  certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email david@davidjbarnes.com || {
    echo "  WARNING: certbot failed. Make sure:"
    echo "    1. DNS for ${DOMAIN} points to this EC2's public IP"
    echo "    2. Security group allows inbound port 80 and 443"
    echo "  You can re-run: certbot certonly --standalone -d ${DOMAIN}"
  }
fi

# --- ECR login helper ---
echo "Configuring ECR access for the EC2 instance..."
# The EC2 instance role should have ECR pull permissions
# Test ECR access:
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "791342033319.dkr.ecr.${AWS_REGION}.amazonaws.com" 2>/dev/null && echo "  ECR login successful" || echo "  WARNING: ECR login failed — ensure EC2 instance role has ecr:GetAuthorizationToken permission"

echo ""
echo "=== EC2 Bootstrap Complete ==="
echo "Env file:   /opt/gratitude/.env"
echo "PostgreSQL: localhost:5432/gratitude"
echo "SSL cert:   /etc/letsencrypt/live/${DOMAIN}/"
echo ""
echo "Next: Push to main branch to trigger CI/CD deployment"
