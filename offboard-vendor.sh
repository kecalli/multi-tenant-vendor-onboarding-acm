#!/usr/bin/env bash
# =============================================================================
# offboard-vendor.sh
# Removes all ACM onboarding resources for a given vendor.
#
# Usage:
#   ./offboard-vendor.sh --vendor <vendor-name> [OPTIONS]
#
# Options:
#   --vendor      <name>   Required. Vendor identifier, e.g. "vendor-a"
#   --dry-run              Print what would be deleted without deleting
#   --force                Skip confirmation prompts
#   --help                 Show this help
#
# What this removes:
#   - ACM Policy, Placement, PlacementBinding
#   - ConsoleLink (Quay registry shortcut)
#   - Namespace and ALL contents (RBAC, quotas, network policies, workloads)
#
# Examples:
#   ./offboard-vendor.sh --vendor vendor-a
#   ./offboard-vendor.sh --vendor vendor-a --dry-run
#   ./offboard-vendor.sh --vendor vendor-a --force
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------
VENDOR=""
DRY_RUN=false
FORCE=false

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

delete_resource() {
  local kind="$1"
  local name="$2"
  local namespace="${3:-}"

  local ns_flag=""
  [[ -n "$namespace" ]] && ns_flag="-n ${namespace}"

  if oc get "$kind" "$name" $ns_flag &>/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "    [DRY RUN] would delete: ${kind}/${name}${namespace:+ in ${namespace}}"
    else
      oc delete "$kind" "$name" $ns_flag
      info "Deleted ${kind}/${name}${namespace:+ in ${namespace}}"
    fi
  else
    echo "    [SKIP] ${kind}/${name} not found${namespace:+ in ${namespace}}"
  fi
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vendor)   VENDOR="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --force)    FORCE=true; shift ;;
    --help|-h)  usage ;;
    *) error "Unknown option: $1" ;;
  esac
done

# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------
[[ -z "$VENDOR" ]] && error "--vendor is required. Run with --help for usage."

if ! command -v oc &>/dev/null; then
  error "'oc' CLI not found."
fi
if ! oc whoami &>/dev/null; then
  error "Not logged into OpenShift. Run 'oc login' first."
fi

# --------------------------------------------------------------------------
# Header
# --------------------------------------------------------------------------
echo ""
echo "============================================="
echo " ACM Vendor Offboarding"
echo "============================================="
echo " Vendor      : ${VENDOR}"
echo " Namespace   : ${VENDOR}-apps"
echo " SSO User    : ${VENDOR}-user"
echo "============================================="
echo ""
echo "  The following resources will be deleted:"
echo "    Policy           : policy-onboard-${VENDOR} (open-cluster-management-policies)"
echo "    Placement        : placement-onboard-${VENDOR} (open-cluster-management-policies)"
echo "    PlacementBinding : binding-onboard-${VENDOR} (open-cluster-management-policies)"
echo "    ConsoleLink      : ${VENDOR}-registry-shortcut"
echo "    Namespace        : ${VENDOR}-apps (and ALL contents)"
echo ""

# --------------------------------------------------------------------------
# Dry run — just show what would be deleted
# --------------------------------------------------------------------------
if [[ "$DRY_RUN" == true ]]; then
  echo "  [DRY RUN] No changes will be made."
  echo ""
  delete_resource policy "policy-onboard-${VENDOR}" "open-cluster-management-policies"
  delete_resource placement "placement-onboard-${VENDOR}" "open-cluster-management-policies"
  delete_resource placementbinding "binding-onboard-${VENDOR}" "open-cluster-management-policies"
  delete_resource consolelink "${VENDOR}-registry-shortcut"
  delete_resource namespace "${VENDOR}-apps"
  echo ""
  info "Dry run complete. No changes made."
  exit 0
fi

# --------------------------------------------------------------------------
# Confirmation
# --------------------------------------------------------------------------
if [[ "$FORCE" == false ]]; then
  echo "  WARNING: Deleting the namespace will permanently remove ALL workloads,"
  echo "           data, and resources inside ${VENDOR}-apps. This cannot be undone."
  echo ""
  read -r -p "  Type the vendor name to confirm deletion: " confirm
  if [[ "$confirm" != "$VENDOR" ]]; then
    info "Confirmation did not match. Aborted."
    exit 0
  fi
fi

# --------------------------------------------------------------------------
# Delete resources
# --------------------------------------------------------------------------
echo ""
info "Removing ACM policy resources..."
delete_resource policy           "policy-onboard-${VENDOR}"  "open-cluster-management-policies"
delete_resource placement        "placement-onboard-${VENDOR}" "open-cluster-management-policies"
delete_resource placementbinding "binding-onboard-${VENDOR}"  "open-cluster-management-policies"

info "Removing ConsoleLink..."
delete_resource consolelink "${VENDOR}-registry-shortcut"

info "Removing namespace and all contents..."
echo ""
echo "  NOTE: Namespace deletion can sometimes hang in OpenShift when ACM-managed"
echo "        resources inside it are still being reconciled. If the namespace gets"
echo "        stuck in 'Terminating' state, force-remove it with:"
echo ""
echo "          oc get namespace ${VENDOR}-apps -o json \\"
echo "            | jq '.spec.finalizers = []' \\"
echo "            | oc replace --raw /api/v1/namespaces/${VENDOR}-apps/finalize -f -"
echo ""
delete_resource namespace "${VENDOR}-apps"

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "============================================="
echo " Offboarding complete: ${VENDOR}"
echo "============================================="
echo ""
echo "  Removed:"
echo "    Policy, Placement, PlacementBinding"
echo "    ConsoleLink"
echo "    Namespace ${VENDOR}-apps and all contents"
echo ""
echo "  Note: The Keycloak user '${VENDOR}-user' has NOT been removed."
echo "        Remove them manually from your IdP if no longer needed."
echo ""
info "Verify with:"
info "oc get policy policy-onboard-${VENDOR} -n open-cluster-management-policies"
info "oc get namespace ${VENDOR}-apps"
echo ""
