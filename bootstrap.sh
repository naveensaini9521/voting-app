#!/bin/bash
set -e

NAMESPACE="voting-app"

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

sleep 10

if ! docker images | grep -q "result-app"; then
    docker build -t naveen9521/result-app:latest ./result
    minikube image load naveen9521/result-app:latest
fi

if ! docker images | grep -q "worker-app"; then
    docker build -t naveen9521/worker-app:latest ./worker
    minikube image load naveen9521/worker-app:latest
fi

echo "Creating namespace..."

kubectl create namespace ${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying application..."

kubectl apply -f k8s-specifications/ -n ${NAMESPACE}

kubectl rollout restart deployment/result -n ${NAMESPACE}
kubectl rollout restart deployment/vote -n ${NAMESPACE}
kubectl rollout restart deployment/worker -n ${NAMESPACE}

echo "Waiting for StatefulSets..."

kubectl rollout status statefulset/db -n ${NAMESPACE}
kubectl rollout status statefulset/redis -n ${NAMESPACE}

echo "Waiting for Deployments..."

kubectl rollout status deployment/vote -n ${NAMESPACE}
kubectl rollout status deployment/worker -n ${NAMESPACE}
kubectl rollout status deployment/result -n ${NAMESPACE}

MINIKUBE_IP=$(minikube ip)

if grep -q "votingapp.local" /etc/hosts; then
    sudo sed -i "/votingapp.local/d" /etc/hosts
fi

# echo "${MINIKUBE_IP} votingapp.local" | sudo tee -a /etc/hosts >/dev/null

echo
echo "Deployment completed successfully!"
echo
echo "Vote App   : http://votingapp.local/"
echo "Result App : http://votingapp.local/result"
echo

kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get ingress -n ${NAMESPACE}

echo "127.0.0.1 votingapp.local" | sudo tee -a /etc/hosts

echo
echo "Opening Minikube Dashboard..."
minikube dashboard