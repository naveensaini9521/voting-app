#!/bin/bash
set -e

NAMESPACE="voting-app"
RESULT_TAG="v1.0.0"
WORKER_TAG="v1.0.0"

echo "Starting Minikube..."

if ! minikube status >/dev/null 2>&1; then
    minikube start --driver=docker --cpus=2 --memory=4096
fi

echo "Enabling addons..."
minikube addons enable ingress
minikube addons enable metrics-server

echo "Waiting for Ingress Controller..."

kubectl rollout status deployment/ingress-nginx-controller \
    -n ingress-nginx \
    --timeout=300s

kubectl wait \
    --namespace ingress-nginx \
    --for=condition=Ready pod \
    -l app.kubernetes.io/component=controller \
    --timeout=300s

echo "Starting Minikube tunnel..."

# Stop any existing tunnel
sudo pkill -f "^minikube tunnel" 2>/dev/null || true
sudo -v
(
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done
) &
SUDO_KEEPALIVE_PID=$!

nohup sudo env \
    "HOME=$HOME" \
    "KUBECONFIG=$HOME/.kube/config" \
    "MINIKUBE_HOME=$HOME/.minikube" \
    "PATH=$PATH" \
    minikube tunnel > /tmp/minikube-tunnel.log 2>&1 &
TUNNEL_PID=$!
disown "$TUNNEL_PID"

echo "Waiting for tunnel to start..."
TUNNEL_OK=0
for i in {1..20}; do
    if grep -qiE "Status:|Tunnel successfully started|NOTE: Please" /tmp/minikube-tunnel.log 2>/dev/null; then
        TUNNEL_OK=1
        break
    fi
    if grep -qi "not found" /tmp/minikube-tunnel.log 2>/dev/null; then
        echo "Tunnel failed to start:"
        cat /tmp/minikube-tunnel.log
        exit 1
    fi
    sleep 1
done

if [ "$TUNNEL_OK" -eq 0 ]; then
    echo "Could not confirm tunnel startup, continuing anyway. Log so far:"
    cat /tmp/minikube-tunnel.log
fi

sleep 3

if ! docker image inspect "naveen9521/result-app:${RESULT_TAG}" >/dev/null 2>&1; then
    echo "Building result-app:${RESULT_TAG}..."
    docker build -t "naveen9521/result-app:${RESULT_TAG}" ./result
fi

minikube image load "naveen9521/result-app:${RESULT_TAG}"

if ! docker image inspect "naveen9521/worker-app:${WORKER_TAG}" >/dev/null 2>&1; then
    echo "Building worker-app:${WORKER_TAG}..."
    docker build -t "naveen9521/worker-app:${WORKER_TAG}" ./worker
fi

minikube image load "naveen9521/worker-app:${WORKER_TAG}"

echo "Creating namespace..."

kubectl create namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying application..."

kubectl apply -f k8s-specifications/ -n "${NAMESPACE}"

echo "Creating TLS secret if missing..."

kubectl rollout restart deployment/result -n "${NAMESPACE}"
kubectl rollout restart deployment/vote -n "${NAMESPACE}"
kubectl rollout restart deployment/worker -n "${NAMESPACE}"

echo "Waiting for StatefulSets..."

kubectl rollout status statefulset/db -n "${NAMESPACE}"
kubectl rollout status statefulset/redis -n "${NAMESPACE}"

echo "Waiting for Deployments..."

kubectl rollout status deployment/vote -n "${NAMESPACE}"
kubectl rollout status deployment/worker -n "${NAMESPACE}"
kubectl rollout status deployment/result -n "${NAMESPACE}"

echo "Updating /etc/hosts..."

if grep -q "votingapp.local" /etc/hosts; then
    sudo sed -i.bak '/votingapp.local/d' /etc/hosts
fi

echo "127.0.0.1 votingapp.local" | sudo tee -a /etc/hosts >/dev/null

echo
echo "Deployment completed successfully!"
echo "Vote App"
echo "  http://votingapp.local/"
echo
echo "Result App"
echo "  http://votingapp.local/result"
echo

kubectl get pods -n "${NAMESPACE}"
kubectl get svc -n "${NAMESPACE}"
kubectl get ingress -n "${NAMESPACE}"