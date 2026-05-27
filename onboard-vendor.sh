#!/usr/bin/env bash
# =============================================================================
# onboard-vendor.sh
# Renders and applies ACM vendor onboarding resources from templates.
#
# Usage:
#   ./onboard-vendor.sh --vendor <vendor-name> [OPTIONS]
#
# Options:
#   --vendor      <name>   Required. Vendor identifier, e.g. "vendor-a" (lowercase, no spaces)
#   --quay-host   <host>   Quay hostname. Default: quay-server.apps.platform-customer.com
#   --dry-run              Print rendered YAML only, do not apply
#   --output      <dir>    Write rendered YAML files to directory instead of applying
#   --template    <file>   Path to policy template. Default: 1-master-onboarding-policy.yaml
#   --workloads   <dir>    Path to workload manifests dir. Default: example-vendor-applications/workloads
#   --skip-preflight       Skip platform preflight checks (use with caution)
#   --help                 Show this help
#
# Examples:
#   ./onboard-vendor.sh --vendor acme-corp
#   ./onboard-vendor.sh --vendor acme-corp --dry-run
#   ./onboard-vendor.sh --vendor acme-corp --output /tmp/rendered/
#   ./onboard-vendor.sh --vendor acme-corp --quay-host quay.mycompany.com
#
# Prerequisites (one-time platform setup, run before first vendor):
#   oc apply -f 0-platform-console-policy.yaml
#
# Note: GitOps integration (ACM Subscription/Channel) is not yet implemented.
#       Workload manifests are applied directly via oc apply for now.
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------
VENDOR=""
QUAY_HOST="quay-server.apps.platform-customer.com"
DRY_RUN=false
OUTPUT_DIR=""
SKIP_PREFLIGHT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_TEMPLATE="${SCRIPT_DIR}/1-master-onboarding-policy.yaml"
WORKLOADS_DIR="${SCRIPT_DIR}/example-vendor-applications/workloads"

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
usage() {
  sed -n '/^# Usage:/,/^# =====/p' "$0" | grep '^#' | sed 's/^# \?//'
  exit 0
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "  --> $*"
}

warn() {
  echo "  [WARN] $*"
}

validate_vendor_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    error "Vendor name '${name}' is invalid. Use lowercase letters, numbers, and hyphens only (e.g. 'vendor-a', 'acme-corp')."
  fi
}

render() {
  local template="$1"
  sed "s/generic-vendor/${VENDOR}/g" "$template" \
    | sed "s|quay-server.apps.platform-customer.com|${QUAY_HOST}|g"
}

check_oc() {
  if ! command -v oc &>/dev/null; then
    error "'oc' CLI not found. Install it or use --dry-run / --output to render YAML without applying."
  fi
  if ! oc whoami &>/dev/null; then
    error "Not logged into OpenShift. Run 'oc login' first."
  fi
}

# --------------------------------------------------------------------------
# Preflight checks
# --------------------------------------------------------------------------
run_preflight() {
  echo ""
  echo "  Running preflight checks..."

  local failed=false

  if ! oc get policy policy-platform-console-vendor-isolation \
       -n open-cluster-management-policies &>/dev/null 2>&1; then
    warn "Platform console policy not found."
    warn "Run: oc apply -f 0-platform-console-policy.yaml"
    failed=true
  else
    info "Platform console policy: OK"
  fi

  if [[ "$failed" == true ]]; then
    echo ""
    echo "  One or more preflight checks failed. Apply the missing platform"
    echo "  resources above and re-run, or use --skip-preflight to bypass."
    echo ""
    exit 1
  fi

  info "All preflight checks passed."
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vendor)           VENDOR="$2";          shift 2 ;;
    --quay-host)        QUAY_HOST="$2";        shift 2 ;;
    --dry-run)          DRY_RUN=true;          shift   ;;
    --output)           OUTPUT_DIR="$2";       shift 2 ;;
    --template)         POLICY_TEMPLATE="$2";  shift 2 ;;
    --workloads)        WORKLOADS_DIR="$2";    shift 2 ;;
    --skip-preflight)   SKIP_PREFLIGHT=true;   shift   ;;
    --help|-h)          usage ;;
    *) error "Unknown option: $1" ;;
  esac
done

# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------
[[ -z "$VENDOR" ]] && error "--vendor is required. Run with --help for usage."
validate_vendor_name "$VENDOR"
[[ ! -f "$POLICY_TEMPLATE" ]]  && error "Policy template not found: ${POLICY_TEMPLATE}"
[[ ! -d "$WORKLOADS_DIR" ]]    && error "Workloads directory not found: ${WORKLOADS_DIR}"

# --------------------------------------------------------------------------
# Render policy template
# --------------------------------------------------------------------------
RENDERED_POLICY=$(render "$POLICY_TEMPLATE")

# --------------------------------------------------------------------------
# Header
# --------------------------------------------------------------------------
echo ""
echo "============================================="
echo " ACM Vendor Onboarding"
echo "============================================="
echo " Vendor      : ${VENDOR}"
echo " Namespace   : ${VENDOR}-apps"
echo " SSO User    : ${VENDOR}-user"
echo " Quay URL    : https://${QUAY_HOST}/${VENDOR}"
echo " Policy tmpl : ${POLICY_TEMPLATE}"
echo " Workloads   : ${WORKLOADS_DIR}"
echo "============================================="

# --------------------------------------------------------------------------
# Dry run
# --------------------------------------------------------------------------
if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "--- DRY RUN: Rendered policy YAML ---"
  echo ""
  echo "$RENDERED_POLICY"
  echo ""
  echo "--- DRY RUN: Workload manifests (applied as-is) ---"
  echo ""
  for f in "${WORKLOADS_DIR}"/*.yaml; do
    echo "### $f"
    cat "$f"
    echo ""
  done
  echo "--- End of rendered YAML ---"
  echo ""
  info "Dry run complete. No changes applied."
  exit 0
fi

# --------------------------------------------------------------------------
# Output to directory
# --------------------------------------------------------------------------
if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
  POLICY_OUT="${OUTPUT_DIR}/${VENDOR}-onboarding-policy.yaml"
  echo "$RENDERED_POLICY" > "$POLICY_OUT"
  for f in "${WORKLOADS_DIR}"/*.yaml; do
    cp "$f" "${OUTPUT_DIR}/$(basename "$f")"
  done
  echo ""
  info "Rendered YAML written to: ${OUTPUT_DIR}"
  info "Review, then apply with:"
  info "  oc apply -f ${POLICY_OUT}"
  info "  oc apply -f ${OUTPUT_DIR}/ -n ${VENDOR}-apps"
  exit 0
fi

# --------------------------------------------------------------------------
# Apply to cluster
# --------------------------------------------------------------------------
check_oc

[[ "$SKIP_PREFLIGHT" == false ]] && run_preflight

echo ""

# Check if vendor already exists
if oc get policy "policy-onboard-${VENDOR}" \
     -n open-cluster-management-policies &>/dev/null 2>&1; then
  echo "  WARNING: Policy 'policy-onboard-${VENDOR}' already exists."
  read -r -p "           Overwrite? (y/N) " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
fi

# Apply policy (creates namespace, RBAC, quotas, NetworkPolicy, ConsoleLink)
info "Applying onboarding policy..."
echo "$RENDERED_POLICY" | oc apply -f -

# Wait for namespace to be active before applying workloads
info "Waiting for namespace ${VENDOR}-apps to be active..."
oc wait namespace "${VENDOR}-apps" \
  --for=jsonpath='{.status.phase}'=Active \
  --timeout=60s

# Apply workload manifests directly into the vendor namespace
info "Applying workload manifests..."
oc apply -f "${WORKLOADS_DIR}/" -n "${VENDOR}-apps"

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "============================================="
echo " Onboarding complete: ${VENDOR}"
echo "============================================="
echo ""
echo "  Provisioned:"
echo "    Namespace     : ${VENDOR}-apps"
echo "    RoleBinding   : ${VENDOR}-admin-binding"
echo "    ResourceQuota : ${VENDOR}-quota"
echo "    LimitRange    : ${VENDOR}-limits"
echo "    NetworkPolicy : default-deny + allow rules"
echo "    ConsoleLink   : ${VENDOR}-registry-shortcut"
echo "    Workloads     : $(ls "${WORKLOADS_DIR}"/*.yaml | wc -l | tr -d ' ') manifest(s) applied from ${WORKLOADS_DIR}"
echo ""
echo "  Verify with:"
info "oc get policy policy-onboard-${VENDOR} -n open-cluster-management-policies"
info "oc get namespace ${VENDOR}-apps"
info "oc get all -n ${VENDOR}-apps"
echo ""
