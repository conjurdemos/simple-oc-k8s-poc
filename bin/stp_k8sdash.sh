#!/bin/bash
source ../config/dap.config
kubectl delete -f $DAP_HOME/bin/k8sdashboard.yaml
