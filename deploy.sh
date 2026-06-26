#!/bin/bash
# Usage: cp deploy.env.example deploy.env && edit && ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"
[[ -f deploy.env ]] && set -a && source deploy.env && set +a

: "${NAMESPACE:=langfuse}"
: "${RELEASE_NAME:=langfuse}"
: "${CHART_VERSION:=1.5.36}"
: "${NODE_PORT:=30080}"
: "${VALUES_FILE:=values-minimal.yaml}"
: "${LANGFUSE_SALT:?Set LANGFUSE_SALT in deploy.env}"
: "${LANGFUSE_ENCRYPTION_KEY:?Set LANGFUSE_ENCRYPTION_KEY in deploy.env}"
: "${LANGFUSE_NEXTAUTH_SECRET:?Set LANGFUSE_NEXTAUTH_SECRET in deploy.env}"
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in deploy.env}"
: "${CLICKHOUSE_PASSWORD:?Set CLICKHOUSE_PASSWORD in deploy.env}"
: "${REDIS_PASSWORD:?Set REDIS_PASSWORD in deploy.env}"
: "${NEXTAUTH_URL:?Set NEXTAUTH_URL in deploy.env}"

helm repo add langfuse https://langfuse.github.io/langfuse-k8s 2>/dev/null || true
helm repo update langfuse

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

export LANGFUSE_SALT LANGFUSE_ENCRYPTION_KEY LANGFUSE_NEXTAUTH_SECRET \
       POSTGRES_PASSWORD CLICKHOUSE_PASSWORD REDIS_PASSWORD NEXTAUTH_URL NODE_PORT

envsubst '${LANGFUSE_SALT} ${LANGFUSE_ENCRYPTION_KEY} ${LANGFUSE_NEXTAUTH_SECRET} ${POSTGRES_PASSWORD} ${CLICKHOUSE_PASSWORD} ${REDIS_PASSWORD} ${NEXTAUTH_URL} ${NODE_PORT}' \
  < "$VALUES_FILE" > /tmp/langfuse-values-rendered.yaml

# Note: --wait often times out on first install while migrations run (10-20 min).
# Omit --wait and monitor: kubectl logs -n langfuse deploy/langfuse-web -f
helm upgrade --install "$RELEASE_NAME" langfuse/langfuse \
  -n "$NAMESPACE" \
  -f /tmp/langfuse-values-rendered.yaml \
  --version "$CHART_VERSION"

rm -f /tmp/langfuse-values-rendered.yaml

echo ""
echo "Install submitted (values: $VALUES_FILE). First boot takes 10-20 minutes."
echo "Do NOT restart langfuse-web until migrations finish."
echo "Watch: kubectl get pods -n $NAMESPACE -w"
echo "Logs:  kubectl logs -n $NAMESPACE deploy/langfuse-web -f"
echo "UI:    ${NEXTAUTH_URL}"
