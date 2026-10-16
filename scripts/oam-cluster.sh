#!/bin/bash
# Creates the Kubernetes cluster that processes OAM uploads, using OAM's own
# recipe (Talos + Argo, `just k8s cluster-init`), and writes .oam-kubeconfig
# so the uploader container can submit workflows to it.
#
# Safe to run again: an existing cluster is reused.

set -euo pipefail
cd "$(dirname "$0")/.."

OAM_DIR="${OAM_DIR:-../openaerialmap}"
# Fixed by OAM's Justfile (`just k8s` passes --set cluster_name).
CLUSTER=oam-uploader-test
NAMESPACE=argo
CONTROLPLANE="${CLUSTER}-controlplane-1"
# Talos 1.14 fails to boot inside Docker Desktop ("failed to set up /etc
# overlay"). OAM's recipe installs the latest talosctl, and talosctl picks
# the node image, so pin a version that boots.
TALOS_VERSION="${OAM_TALOS_VERSION:-v1.13.11}"
BIN_DIR="$PWD/.bin"

if [ ! -d "$OAM_DIR" ]; then
    echo "❌ OpenAerialMap not found at $OAM_DIR (set OAM_DIR)"
    exit 1
fi
for tool in just kubectl docker curl; do
    if ! command -v "$tool" > /dev/null; then
        echo "❌ $tool is required"
        exit 1
    fi
done

# --- Pinned talosctl, found first on PATH by OAM's recipe -------------------
if ! "$BIN_DIR/talosctl" version --client --short 2>/dev/null | grep -q "$TALOS_VERSION"; then
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$(uname -m)" in
        x86_64 | amd64) arch=amd64 ;;
        arm64 | aarch64) arch=arm64 ;;
        *) echo "❌ Unsupported architecture $(uname -m)"; exit 1 ;;
    esac
    echo "📦 Installing talosctl $TALOS_VERSION in .bin/..."
    mkdir -p "$BIN_DIR"
    curl -fsSL -o "$BIN_DIR/talosctl" \
        "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-${os}-${arch}"
    chmod +x "$BIN_DIR/talosctl"
fi
export PATH="$BIN_DIR:$PATH"

# --- Reachable API address ---------------------------------------------------
# talosctl writes the node's Docker IP (10.5.0.2) as the API address. Docker
# Desktop does not route container IPs to the host, so point kubectl at the
# port Docker publishes instead, still checking the certificate against the
# node IP it was issued for.
api_port() {
    docker port "$CONTROLPLANE" 6443/tcp 2>/dev/null | head -1 | awk -F: '{print $NF}'
}
node_ip() {
    docker inspect -f "{{(index .NetworkSettings.Networks \"$CLUSTER\").IPAddress}}" "$CONTROLPLANE"
}
use_published_port() {
    local port
    port=$(api_port)
    [ -n "$port" ] || return 1
    kubectl config get-clusters 2>/dev/null | grep -qx "$CLUSTER" || return 1
    kubectl config set-cluster "$CLUSTER" --server="https://127.0.0.1:${port}" \
        --tls-server-name="$(node_ip)" > /dev/null
    kubectl config use-context "admin@${CLUSTER}" > /dev/null
}

# On a new cluster, OAM's recipe merges the kubeconfig and then waits for the
# nodes, so fix the address in the background while it runs. Keep watching
# until the script ends: talosctl writes the kubeconfig more than once, the
# last time with the node IP.
use_published_port || true
(
    while true; do
        if [ "$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CLUSTER\")].cluster.server}" 2>/dev/null)" != "https://127.0.0.1:$(api_port)" ]; then
            use_published_port || true
        fi
        sleep 5
    done
) &
WATCHER=$!
trap 'kill "$WATCHER" 2>/dev/null || true' EXIT

# --- Cluster, Argo and OAM's pipeline ----------------------------------------
# cluster-available creates or reuses the cluster and applies OAM's
# WorkflowTemplate with its local resource limits.
(cd "$OAM_DIR" && just test cluster-available)
use_published_port

# The WorkflowTemplate reads the S3 keys from this secret. Same keys as
# oam-rustfs in docker-compose.yml.
kubectl create secret generic oam-s3-creds -n "$NAMESPACE" \
    --from-literal=S3_ACCESS_KEY=oam \
    --from-literal=S3_SECRET_KEY=oam \
    --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# The WorkflowTemplate keeps the API token out of step containers, so Argo's
# executor mounts this Secret instead. OAM's Helm chart creates it in
# production; OAM's local recipe does not, and without it every step pod
# waits in Init forever.
kubectl apply -f - > /dev/null <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: argo-odm.service-account-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: argo-odm
type: kubernetes.io/service-account-token
YAML

# --- Kubeconfig for the uploader container -----------------------------------
# Containers reach the published port through host.docker.internal.
# set-cluster drops tls-server-name when the server changes, so pass it again.
TMP_KUBECONFIG=$(mktemp)
kubectl config view --raw --minify --flatten --context "admin@${CLUSTER}" > "$TMP_KUBECONFIG"
KUBECONFIG="$TMP_KUBECONFIG" kubectl config set-cluster "$CLUSTER" \
    --server="https://host.docker.internal:$(api_port)" \
    --tls-server-name="$(node_ip)" > /dev/null
# Copy over the file instead of replacing it: a running uploader has it
# bind-mounted and would keep reading the old one.
touch .oam-kubeconfig
chmod 600 .oam-kubeconfig
cat "$TMP_KUBECONFIG" > .oam-kubeconfig
rm -f "$TMP_KUBECONFIG"

echo ""
echo "✅ OAM processing cluster ready"
echo "   Kubeconfig for the uploader: .oam-kubeconfig"
echo "   Workflows: kubectl -n $NAMESPACE get workflows"
