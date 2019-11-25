#!/bin/bash
source ../config/dap.config

TOKEN=$(kubectl -n kube-system describe secret default| awk '$1=="token:"{print $2}')
kubectl config set-credentials kubernetes-admin --token="${TOKEN}"
kubectl apply -f $DAP_HOME/bin/k8sdashboard.yaml
kubectl proxy &> /dev/null &
echo "Admin token: $TOKEN"
