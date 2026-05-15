#!/bin/bash
# Kubernetes Deployment Script
# Purpose: Deploy Medicine Stock application to Kubernetes cluster

set -e

echo "================================================"
echo "  Kubernetes Deployment - Medicine Stock API"
echo "================================================"
echo ""

K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../k8s" && pwd)"
cd "$K8S_DIR"

echo "Working directory: $K8S_DIR"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace medicine-stock &> /dev/null; then
    log_warn "Namespace medicine-stock not found."
    log_info "Please run Terraform (Phase 3) first to create infrastructure."
    exit 1
fi

log_info "✓ Prerequisites met"
echo ""

# Apply manifests
log_info "Applying Kubernetes manifests..."

log_info "1. Applying deployment.yaml..."
kubectl apply -f deployment.yaml
log_info "   ✓ Deployment created/updated"

log_info "2. Applying service.yaml..."
kubectl apply -f service.yaml
log_info "   ✓ Service created/updated"

echo ""

# Wait for rollout
log_info "Waiting for deployment rollout (timeout: 5 minutes)..."
if kubectl rollout status deployment/medicine-stock -n medicine-stock --timeout=5m; then
    log_info "✓ Deployment rollout successful"
else
    log_error "Deployment rollout failed or timed out"
    exit 1
fi

echo ""

# Display deployment status
log_info "Deployment Status:"
echo ""

kubectl get deployment medicine-stock -n medicine-stock
echo ""

log_info "Pod Status:"
kubectl get pods -n medicine-stock -l app=medicine-stock
echo ""

log_info "Service Status:"
kubectl get svc medicine-stock-service -n medicine-stock
echo ""

# Get pod details
log_info "Pod Details:"
kubectl get pods -n medicine-stock -l app=medicine-stock -o wide
echo ""

# Display access information
log_info "Access Information:"
echo ""

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

if [ -n "$NODE_IP" ]; then
    echo "✓ NodePort Access: http://$NODE_IP:30081"
else
    echo "✓ NodePort: 30081 (use your node IP)"
fi

echo "✓ Internal Service: http://medicine-stock-service:5000"
echo ""

# Port-forward hint
log_info "Port-forward for local testing:"
echo "kubectl port-forward svc/medicine-stock-service 5000:5000 -n medicine-stock"
echo ""

# Test endpoint
log_info "Testing API endpoint..."
ATTEMPTS=0
MAX_ATTEMPTS=10

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if kubectl exec -it $(kubectl get pod -n medicine-stock -l app=medicine-stock -o jsonpath='{.items[0].metadata.name}') -n medicine-stock -- curl -s http://localhost:5000/ > /dev/null 2>&1; then
        log_info "✓ API endpoint is responding"
        break
    fi
    
    echo "Attempt $((ATTEMPTS+1))/$MAX_ATTEMPTS..."
    ATTEMPTS=$((ATTEMPTS+1))
    sleep 2
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    log_warn "Could not verify API endpoint (may still be starting)"
fi

echo ""
echo "================================================"
log_info "✓ Kubernetes Deployment Complete"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Check logs:    kubectl logs -f deployment/medicine-stock -n medicine-stock"
echo "2. Port-forward:  kubectl port-forward svc/medicine-stock-service 5000:5000 -n medicine-stock"
echo "3. Test API:      curl http://localhost:5000/"
echo "4. Scale pods:    kubectl scale deployment medicine-stock --replicas=3 -n medicine-stock"
echo ""
