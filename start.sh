#!/bin/bash
 
minikube stop
minikube start

minikube addons enable ingress

minikube addons enable metrics-server
 
kubectl create namespace voting-app
 
kubectl apply -f k8s-specifications/ -n voting-app
 
echo "127.0.0.1 votingapp.local" | sudo tee -a /etc/hosts
 
minikube dashboard
 