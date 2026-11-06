#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  --namespaces)
    printf 'Deleting namespaces wordpress and prestashop also deletes their PVCs and data.\n'
    kubectl delete namespace wordpress prestashop --ignore-not-found --wait=true
    ;;
  --azure)
    printf 'Running azd down removes the complete azd environment and its persistent data.\n'
    azd down
    ;;
  *)
    printf 'Usage: %s --namespaces | --azure\n' "$0" >&2
    printf '  --namespaces  Delete only the two application namespaces and their data.\n' >&2
    printf '  --azure       Run azd down to delete the complete Azure environment.\n' >&2
    exit 2
    ;;
esac
