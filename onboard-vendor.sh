#!/usr/bin/env bash
# =============================================================================
# onboard-vendor.sh
# Renders and applies an ACM vendor onboarding policy from a template.
#
# Usage:
#   ./onboard-vendor.sh --vendor <vendor-name> [OPTIONS]
#
# Options:
#   --vendor      <name>   Required. Vendor identifier, e.g. "vendor-a" (lowercase, no spaces)
#   --quay-host   <host>   Quay hostname. Default: quay-server.apps.platform-customer.com
#   --dry-run              Print rendered YAML only, do not apply
#   --output      <file>   Write rendered YAML to file instead of applying
#   --template    <file>   Path to template file. Default: 1-master-onboarding-policy.yaml
#   --help                 Show this help
#
# Examples:
#   ./onboard-vendor.sh --vendor acme-corp
#   ./onboard-vendor.sh --vendor acme-corp --dry-run
#   ./onboard-vendor.sh --vendor acme-corp --output /tmp/acme-corp-policy.yaml
#   ./onboard-vendor.sh --vendor acme-corp --quay-host quay.mycompany.com
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------
VENDOR=""
QUAY_HOST="quay-server.apps.platform-customer.com"
DRY_RUN=false
OUTPUT_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/1-master-onboarding-policy.yaml"

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

validate_vendor_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    error "Vendor name '${name}' is invalid. Use lowercase letters, numbers, and hyphens only (e.g. 'vendor-a', 'acme-corp')."
  fi
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vendor)     VENDOR="$2";        shift 2 ;;
    --quay-host)  QUAY_HOST="$2";     shift 2 ;;
    --dry-run)    DRY_RUN=true;       shift   ;;
    --output)     OUTPUT_FILE="$2";   shift 2 ;;
    --template)   TEMPLATE_FILE="$2"; shift 2 ;;
    --help|-h)    usage ;;
    *) error "Unknown option: $1" ;;
  esac
done

# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------
[[ -z "$VENDOR" ]] && error "--vendor is required. Run with --help for usage."
validate_vendor_name "$VENDOR"
[[ ! -f "$TEMPLATE_FILE" ]] && error "Template file not found: ${TEMPLATE_FILE}"

# --------------------------------------------------------------------------
# Render
# --------------------------------------------------------------------------
RENDERED=$(sed "s/generic-vendor/${VENDOR}/g" "$TEMPLATE_FILE" \
  | sed "s|quay-server.apps.platform-customer.com|${QUAY_HOST}|g")

# --------------------------------------------------------------------------
# Output / Apply
# --------------------------------------------------------------------------
echo ""
echo "============================================="
echo " ACM Vendor Onboarding"
echo "============================================="
echo " Vendor   : ${VENDOR}"
echo " Namespace: ${VENDOR}-apps"
echo " SSO User : ${VENDOR}-user"
echo " Quay URL : https://${QUAY_HOST}/${VENDOR}"
echo " Template : ${TEMPLATE_FILE}"
echo "============================================="
echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo "--- DRY RUN: Rendered YAML ---"
  echo ""
  echo "$RENDERED"
  echo ""
  echo "--- End of rendered YAML ---"
  echo ""
  info "Dry run complete. No changes applied."

elif [[ -n "$OUTPUT_FILE" ]]; then
  echo "$RENDERED" > "$OUTPUT_FILE"
  info "Rendered YAML written to: ${OUTPUT_FILE}"
  info "Review it, then apply with: oc apply -f ${OUTPUT_FILE}"

else
  # Check oc is available and we're logged in
  if ! command -v oc &>/dev/null; then
    error "'oc' CLI not found. Install it or use --output to write the YAML and apply manually."
  fi
  if ! oc whoami &>/dev/null; then
    error "Not logged into OpenShift. Run 'oc login' first."
  fi

  # Check if policy already exists
  if oc get policy "policy-onboard-${VENDOR}" -n open-cluster-management-policies &>/dev/null 2>&1; then
    echo "WARNING: Policy 'policy-onboard-${VENDOR}' already exists in open-cluster-management-policies."
    read -r -p "         Overwrite? (y/N) " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
  fi

  info "Applying policy to cluster..."
  echo "$RENDERED" | oc apply -f -
  echo ""
  info "Done. Verify with:"
  info "  oc get policy policy-onboard-${VENDOR} -n open-cluster-management-policies"
  info "  oc get namespace ${VENDOR}-apps"
fi

echo ""
