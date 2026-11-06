#!/usr/bin/env bash
set -euo pipefail

printf '\n== Nodes ==\n'
kubectl get nodes -o wide

printf '\n== Pods in every namespace ==\n'
kubectl get pods -A -o wide

printf '\n== Services in every namespace ==\n'
kubectl get services -A -o wide

printf '\n== PVCs in every namespace ==\n'
kubectl get pvc -A

printf '\n== Deployments in every namespace ==\n'
kubectl get deployments -A

printf '\n== PVC details ==\n'
kubectl describe pvc -n wordpress
kubectl describe pvc -n prestashop

printf '\n== Recent MariaDB logs ==\n'
kubectl logs deployment/mariadb -n wordpress --tail=50
kubectl logs deployment/mariadb -n prestashop --tail=50

printf '\n== Recent application logs ==\n'
kubectl logs deployment/wordpress -n wordpress --tail=50
kubectl logs deployment/prestashop -n prestashop --tail=50
