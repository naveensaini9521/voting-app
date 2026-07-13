# Docker Sample Voting App on Kubernetes with Jenkins CI/CD

![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.33-blue)
![Docker](https://img.shields.io/badge/Docker-Enabled-blue)
![Jenkins](https://img.shields.io/badge/Jenkins-CI-red)
![License](https://img.shields.io/badge/License-MIT-green)

## Table of Contents

- Overview
- Architecture
- Tech Stack
- Repository Structure
- Improvements
- Prerequisites
- Quick Start
- Manual Deployment
- Jenkins Pipeline
- Verification
- Troubleshooting
- Trade-offs
- Future Improvements
- Video Walkthrough
- Author

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

## Architecture

![Architecture](docs/architecture.png)

## Overview

This project demonstrates a production-inspired deployment of the Docker Sample Voting Application on Kubernetes using Minikube.

The solution includes:

- Kubernetes Deployments and StatefulSets
- Jenkins-based CI/CD pipeline
- Docker image versioning using Semantic Versioning
- Kubernetes Secrets for sensitive configuration
- Liveness and Readiness Probes
- NGINX Ingress
- Automatic deployment validation with smoke tests
- Automatic rollback on failed deployments

The application consists of five microservices:

- Vote (Python Flask)
- Worker (.NET)
- Result (Node.js)
- Redis
- PostgreSQL

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
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── worker/
│   ├── Program.cs
│   ├── Worker.csproj
│   └── Dockerfile
├── result/
│   ├── server.js
│   ├── package.json
│   └── Dockerfile
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
├── start.sh
├── bootstrap.sh
└── README.md
```

---

## Key Features

- Production-style Kubernetes deployment
- Jenkins CI/CD pipeline
- Automatic Docker image build and push
- Semantic Versioning
- Kubernetes Secrets
- Stateful PostgreSQL with Persistent Volumes
- Stateful Redis
- Resource Requests & Limits
- Readiness & Liveness Probes
- Automatic Smoke Testing
- Automatic Rollback
- NGINX Ingress

---

## Improvements Over Original Kubernetes Manifests

The original Docker Sample Voting App manifests were functional but not production-ready.

The following improvements were implemented:

```
| Improvement                | Why                                         |
| -------------------------- | ------------------------------------------- |
| Kubernetes Secrets         | Removed database credentials from YAML      |
| StatefulSet for PostgreSQL | Persistent storage across pod restarts      |
| StatefulSet for Redis      | Stable network identity                     |
| Liveness Probes            | Automatic recovery from failures            |
| Readiness Probes           | Prevent traffic before application is ready |
| Resource Requests          | Better scheduling                           |
| Resource Limits            | Prevent noisy neighbor issues               |
| NGINX Ingress              | Browser access without NodePort             |
| Namespace Isolation        | Better resource organization                |
| Jenkins CI/CD              | Automated build and deployment              |
| Semantic Versioning        | Versioned Docker images                     |
| Smoke Testing              | Validate deployment after rollout           |
| Automatic Rollback         | Recover from failed deployments             |
```

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
git --version

```

---

# Start Minikube

```bash
minikube start --cpus=2 --memory=4096 --driver=docker
```

Enable ingress

```bash
minikube addons enable ingress
minikube addons enable metrics-server

```

Verify

```bash
kubectl get nodes
```

---

# Clone Repository

```bash
git clone https://github.com/naveensaini9521/voting-app.git
cd voting-app
```

---

# Run One-Click Deployment

```bash
chmod +x start.sh
./start.sh
```

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

# Ingress not accessible

```bash
minikube tunnel
kubectl get ingress -n voting-app
```

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
- Kustomize
- ArgoCD GitOps
- Horizontal Pod Autoscaler
- Prometheus Monitoring
- Grafana Dashboards
- Trivy Image Scanning
- SonarQube Code Quality
- Network Policies
- Pod Security Context
- Multi-environment Deployments

---

# Author

**Naveen Saini**

GitHub: https://github.com/naveensaini9521

LinkedIn: https://www.linkedin.com/in/naveen-saini-7ba247262/

---
