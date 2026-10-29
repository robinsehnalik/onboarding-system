#!/usr/bin/env bash
# ==============================================================================
# Script: export-workflows.sh
# Purpose: Export and sanitize n8n workflows for the Lean Onboarding System.
# Removes secrets, credentials, and tokens before committing workflow specs.
# ==============================================================================

set -euo pipefail

EXPORT_DIR="${1:-./workflows/exports}"
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"

echo "==> Preparing workflow export directory: ${EXPORT_DIR}"
mkdir -p "${EXPORT_DIR}"

if [[ -z "${N8N_API_KEY}" ]]; then
  echo "Notice: N8N_API_KEY not set. Checking if running inside n8n CLI environment..."
  if command -v n8n >/dev/null 2>&1; then
    echo "Exporting workflows using local n8n CLI..."
    n8n export:workflow --all --output="${EXPORT_DIR}/workflows-raw.json"
  else
    echo "Error: Neither N8N_API_KEY nor n8n CLI is available."
    echo "Usage: N8N_API_KEY=xxx N8N_URL=http://localhost:5678 ./scripts/export-workflows.sh [output_dir]"
    exit 1
  fi
else
  echo "Exporting workflows via n8n REST API from ${N8N_URL}..."
  curl -s -f -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows?limit=100" > "${EXPORT_DIR}/workflows-raw.json"
fi

if [[ -f "${EXPORT_DIR}/workflows-raw.json" ]] && command -v jq >/dev/null 2>&1; then
  echo "Sanitizing sensitive credentials and tokens from exported workflows..."
  jq '
    def sanitize:
      walk(
        if type == "object" then
          del(.credentials) |
          del(.pinData) |
          with_entries(
            if .key | test("token|key|secret|password"; "i") then
              .value = "REDACTED"
            else
              .
            end
          )
        else
          .
        end
      );
    if type == "array" then map(sanitize) else sanitize end
  ' "${EXPORT_DIR}/workflows-raw.json" > "${EXPORT_DIR}/workflows-sanitized.json"

  rm -f "${EXPORT_DIR}/workflows-raw.json"
  echo "==> Successfully exported and sanitized workflows to: ${EXPORT_DIR}/workflows-sanitized.json"
else
  echo "Warning: jq not found or raw export missing; raw output retained."
fi
