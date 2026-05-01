# Cluster Setup

## Start cluster

minikube start

## Verify

kubectl get nodes

## Deploy infra

kubectl apply -f kubernetes/namespaces/dev.yaml
kubectl apply -f kubernetes/mongo/
kubectl apply -f kubernetes/rabbitmq/
