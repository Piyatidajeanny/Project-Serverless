#!/bin/bash
# CI/CD Helper Scripts for Medicine Stock DevOps Project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOCKER_IMAGE="${DOCKER_IMAGE:-medicine-stock}"
DOCKER_TAG="${DOCKER_TAG:-latest}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-default}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function: Build Docker image
build_image() {
    log_info "Building Docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
    docker build -t "${DOCKER_IMAGE}:${DOCKER_TAG}" \
                 -t "${DOCKER_IMAGE}:latest" \
                 -f Dockerfile .
    log_info "Build completed successfully"
}

# Function: Run unit tests
run_tests() {
    log_info "Running unit tests..."
    cd app
    python -m pytest test_app.py -v --tb=short
    cd ..
    log_info "Tests completed"
}

# Function: Test Docker image
test_image() {
    log_info "Testing Docker image..."
    CONTAINER_ID=$(docker run -d -p 5001:5000 -e DB_PATH=/app/medicine.db "${DOCKER_IMAGE}:${DOCKER_TAG}")
    sleep 3
    
    if curl -f http://localhost:5001/ > /dev/null 2>&1; then
        log_info "Container health check passed"
        docker stop "${CONTAINER_ID}"
        docker rm "${CONTAINER_ID}"
        return 0
    else
        log_error "Container health check failed"
        docker stop "${CONTAINER_ID}" || true
        docker rm "${CONTAINER_ID}" || true
        return 1
    fi
}

# Function: Push image to registry
push_image() {
    log_info "Pushing image to registry..."
    docker push "${DOCKER_IMAGE}:${DOCKER_TAG}"
    docker push "${DOCKER_IMAGE}:latest"
    log_info "Image pushed successfully"
}

# Function: Deploy to Kubernetes
deploy_k8s() {
    log_info "Deploying to Kubernetes namespace: ${KUBE_NAMESPACE}"
    
    # Update image in deployment
    kubectl set image deployment/medicine-stock \
            medicine-stock="${DOCKER_IMAGE}:${DOCKER_TAG}" \
            -n "${KUBE_NAMESPACE}" || \
    kubectl apply -f k8s/deployment.yaml -n "${KUBE_NAMESPACE}"
    
    # Apply service
    kubectl apply -f k8s/service.yaml -n "${KUBE_NAMESPACE}"
    
    # Wait for rollout
    kubectl rollout status deployment/medicine-stock \
            -n "${KUBE_NAMESPACE}" --timeout=5m
    
    log_info "Deployment completed"
}

# Function: Display help
show_help() {
    cat << EOF
Usage: ./ci-pipeline.sh [COMMAND]

Commands:
    build       - Build Docker image
    test        - Run unit tests
    test-image  - Test Docker image
    push        - Push image to registry
    deploy      - Deploy to Kubernetes
    all         - Run build, test, and build image
    help        - Show this help message

Environment Variables:
    DOCKER_IMAGE     - Docker image name (default: medicine-stock)
    DOCKER_TAG       - Docker tag (default: latest)
    KUBE_NAMESPACE   - Kubernetes namespace (default: default)

Examples:
    ./ci-pipeline.sh build
    DOCKER_TAG=v1.0 ./ci-pipeline.sh push
    ./ci-pipeline.sh all

EOF
}

# Main execution
case "${1:-help}" in
    build)
        build_image
        ;;
    test)
        run_tests
        ;;
    test-image)
        test_image
        ;;
    push)
        push_image
        ;;
    deploy)
        deploy_k8s
        ;;
    all)
        run_tests
        build_image
        test_image
        ;;
    help)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

log_info "Script execution completed"
