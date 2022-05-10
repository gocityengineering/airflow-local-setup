#!/usr/bin/env bash

if [ -z ${LOCAL_DAGS_FOLDER+x} ];
  then echo "LOCAL_DAGS_FOLDER is unset" && exit 1;
  else echo "LOCAL_DAGS_FOLDER is set to '$LOCAL_DAGS_FOLDER'";
fi

## SET MOUNT PATH TO $LOCAL_DAGS_FOLDER
yq -i "
.nodes[1].extraMounts[1].hostPath = \"$LOCAL_DAGS_FOLDER\" |
.nodes[1].extraMounts[1].containerPath = \"/tmp/dags\"  |
.nodes[2].extraMounts[1].hostPath = \"$LOCAL_DAGS_FOLDER\" |
.nodes[2].extraMounts[1].containerPath = \"/tmp/dags\"  |
.nodes[3].extraMounts[1].hostPath = \"$LOCAL_DAGS_FOLDER\" |
.nodes[3].extraMounts[1].containerPath = \"/tmp/dags\"
" kind-cluster.yaml

## CREATE KUBE CLUSTER
kind create cluster --name airflow-cluster --config kind-cluster.yaml

## CREATE AIRFLOW NAMESPACE
kubectl create namespace airflow

## CREATE WEBSERVER SECRET (FERNET KEY)
kubectl -n airflow create secret generic my-webserver-secret --from-literal="webserver-secret-key=$(python3 -c 'import secrets; print(secrets.token_hex(16))')"

## CREATE PERSISTENT VOLUME AND CLAIM FOR DAGS
kubectl apply -f dags_volume.yaml

## FETCH LATEST HELM CHART VERSION AND INSTALL AIRFLOW
helm repo add apache-airflow https://airflow.apache.org
helm repo update
helm search repo airflow
helm install airflow apache-airflow/airflow --namespace airflow --debug -f values.yaml
