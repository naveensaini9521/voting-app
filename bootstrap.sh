#!/bin/bash
set -e

DOCKER_USER="naveen9521"

echo "Restarting Minikube"
minikube delete 2>/dev/null || true
minikube start --cpus=2 --memory=4096 --driver=docker

echo "Enabling addons"
minikube addons enable ingress
minikube addons enable metrics-server

echo "Building service images"
docker build -t ${DOCKER_USER}/vote-app-project:latest   ./vote
docker build -t ${DOCKER_USER}/worker-app-project:latest ./worker
docker build -t ${DOCKER_USER}/result-app-project:latest ./result

echo "==> Loading images into Minikube"
minikube image load ${DOCKER_USER}/vote-app-project:latest
minikube image load ${DOCKER_USER}/worker-app-project:latest
minikube image load ${DOCKER_USER}/result-app-project:latest

echo "Creating namespace"
kubectl create namespace voting-app --dry-run=client -o yaml | kubectl apply -f -

echo "Applying manifests"
kubectl apply -f k8s-specifications/ -n voting-app

echo "Waiting for pods to be ready"
kubectl wait --namespace voting-app --for=condition=ready pod --all --timeout=300s

MINIKUBE_IP=$(minikube ip)
if ! grep -q "votingapp.local" /etc/hosts; then
    echo "${MINIKUBE_IP} votingapp.local" | sudo tee -a /etc/hosts > /dev/null
fi

echo ""
echo "Deployment complete"
kubectl get pods -n voting-app
kubectl get svc -n voting-app
kubectl get ingress -n voting-app

echo ""
echo "Vote:   http://votingapp.local/"
echo "Result: http://votingapp.local/result"