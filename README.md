# Docker Sample Voting App on Kubernetes with CI/CD

## Overview

This project deploys the Docker Sample Voting Application on Kubernetes using Minikube. It includes a complete CI/CD pipeline using Jenkins that automatically builds, tests, pushes Docker images to Docker Hub, and deploys the application to Kubernetes.

The application consists of five services:

- Vote (Python Flask)
- Worker (.NET)
- Result (Node.js)
- Redis
- PostgreSQL

---

# Architecture

```
                 User
                   |
             Kubernetes Ingress
              /             \
             /               \
        Vote Service      Result Service
             |                  |
             |                  |
          Redis <---------- Worker ---------> PostgreSQL
```

---

# Tech Stack

- Kubernetes
- Minikube
- Docker
- Jenkins
- Docker Hub
- Python (Flask)
- Node.js
- .NET
- Redis
- PostgreSQL
- GitHub

---

# Repository Structure

```
.
├── vote/
├── worker/
├── result/
├── k8s-specifications/
│   ├── namespace.yaml
│   ├── secrets.yaml
│   ├── vote-deployment.yaml
│   ├── vote-service.yaml
│   ├── worker-deployment.yaml
│   ├── result-deployment.yaml
│   ├── result-service.yaml
│   ├── db-statefulset.yaml
│   ├── db-service.yaml
│   ├── redis-statefulset.yaml
│   ├── redis-service.yaml
│   └── ingress.yaml
├── Jenkinsfile
└── README.md
```

---

# Features

- Dockerized microservices
- Kubernetes Deployments
- StatefulSets for PostgreSQL and Redis
- Kubernetes Secrets
- Resource Requests & Limits
- Readiness Probes
- Liveness Probes
- Ingress
- Jenkins CI/CD Pipeline
- Automatic Docker Image Build
- Automatic Deployment to Kubernetes

---

# Prerequisites

Install:

- Docker
- Minikube
- kubectl
- Jenkins
- Git
- Docker Hub Account

Verify installation

```bash
docker --version
kubectl version --client
minikube version
jenkins --version
```

---

# Start Minikube

```bash
minikube start --driver=docker
```

Enable ingress

```bash
minikube addons enable ingress
```

Verify

```bash
kubectl get nodes
```

---

# Clone Repository

```bash
git clone https://github.com/<username>/<repository>.git

cd repository
```

---

# Build Docker Images

Vote

```bash
docker build -t vote-app ./vote
```

Worker

```bash
docker build -t worker-app ./worker
```

Result

```bash
docker build -t result-app ./result
```

---

# Push Images

```bash
docker tag vote-app username/vote-app:v1
docker push username/vote-app:v1
```

Repeat for Worker and Result.

---

# Kubernetes Deployment

Create Namespace

```bash
kubectl apply -f k8s-specifications/namespace.yaml
```

Create Secrets

```bash
kubectl apply -f k8s-specifications/secrets.yaml
```

Deploy PostgreSQL

```bash
kubectl apply -f k8s-specifications/db-service.yaml
kubectl apply -f k8s-specifications/db-statefulset.yaml
```

Deploy Redis

```bash
kubectl apply -f k8s-specifications/redis-service.yaml
kubectl apply -f k8s-specifications/redis-statefulset.yaml
```

Deploy Vote

```bash
kubectl apply -f k8s-specifications/vote-service.yaml
kubectl apply -f k8s-specifications/vote-deployment.yaml
```

Deploy Worker

```bash
kubectl apply -f k8s-specifications/worker-deployment.yaml
```

Deploy Result

```bash
kubectl apply -f k8s-specifications/result-service.yaml
kubectl apply -f k8s-specifications/result-deployment.yaml
```

Deploy Ingress

```bash
kubectl apply -f k8s-specifications/ingress.yaml
```

---

# Verify Deployment

Pods

```bash
kubectl get pods -n voting-app
```

Services

```bash
kubectl get svc -n voting-app
```

StatefulSets

```bash
kubectl get statefulset -n voting-app
```

Ingress

```bash
kubectl get ingress -n voting-app
```

Logs

```bash
kubectl logs deployment/vote -n voting-app

kubectl logs deployment/worker -n voting-app

kubectl logs deployment/result -n voting-app
```

---

# Jenkins Pipeline

Pipeline Stages

1. Clone Repository
2. Build Docker Images
3. Push Images to Docker Hub
4. Update Kubernetes Deployment
5. Deploy to Minikube
6. Verify Deployment

---

# Jenkins Credentials

DockerHub Credentials

```
dockerhub-credentials
```

Kubeconfig

```
kubeconfig-jenkins-token
```

---

# Environment Variables

Vote

```
OPTION_A
OPTION_B
REDIS_HOST
REDIS_PORT
```

Worker

```
POSTGRES_HOST
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
REDIS_HOST
REDIS_PORT
```

Result

```
POSTGRES_HOST
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
```

---

# Changes Made

## Vote Service

Updated Flask application to use Kubernetes Secrets.

Before

```python
host="redis"
```

After

```python
host=os.getenv("REDIS_HOST")
```

---

## Worker Service

Updated Program.cs

Before

```
Server=db
```

After

```
POSTGRES_HOST
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
REDIS_HOST
```

Now Worker reads configuration from Kubernetes Secrets.

---

## Result Service

Updated

```javascript
process.env.POSTGRES_HOST;
process.env.POSTGRES_USER;
process.env.POSTGRES_PASSWORD;
process.env.POSTGRES_DB;
```

instead of hardcoded values.

---

# Problems Faced

## 1. Worker continuously showing "Waiting for db"

Reason

Old PostgreSQL password stored inside Persistent Volume.

Solution

Deleted

- StatefulSet
- PVC

Created fresh PostgreSQL database.

---

## 2. PostgreSQL Password Authentication Failed

Reason

Persistent storage retained old credentials.

Solution

Removed PVC and recreated StatefulSet.

---

## 3. Result Service CrashLoopBackOff

Reason

Liveness Probe failed because application wasn't listening correctly.

Solution

Verified:

- Environment Variables
- Database Connectivity
- Container Port
- Application Startup

---

## 4. Kubernetes Namespace Issue

StatefulSet was accidentally created in the default namespace.

Solution

Added

```yaml
metadata:
  namespace: voting-app
```

to every Kubernetes manifest.

---

## 5. Docker Image Updates

Problem

Using

```
latest
```

caused Kubernetes to reuse cached images.

Solution

Use Jenkins Build Number

Example

```
vote-app:42
vote-app:43
vote-app:44
```

and update deployment automatically.

---

# Useful Commands

Pods

```bash
kubectl get pods -n voting-app
```

Logs

```bash
kubectl logs deployment/worker -n voting-app
```

Restart Deployment

```bash
kubectl rollout restart deployment vote -n voting-app
```

Delete Everything

```bash
kubectl delete namespace voting-app
```

---

# Future Improvements

- Helm Charts
- Horizontal Pod Autoscaler
- Prometheus Monitoring
- Grafana Dashboard
- ArgoCD GitOps
- Image Versioning
- SonarQube Integration
- Trivy Security Scan
- GitHub Actions Support

---

# Author

**Naveen Saini**

GitHub: https://github.com/naveensaini9521

LinkedIn: https://www.linkedin.com/in/naveen-saini-7ba247262/

---
