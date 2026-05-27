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

# Wait briefly for ACM to stop reconciling after policy deletion
info "Waiting for ACM to stop reconciling (10s)..."
sleep 10

info "Removing all resources from namespace ${VENDOR}-apps..."
if oc get namespace "${VENDOR}-apps" &>/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "    [DRY RUN] would delete all resources in namespace ${VENDOR}-apps"
  else
    # Explicitly delete known workload resource types to avoid finalizer hangs
    for resource_type in deployments services routes configmaps rolebindings resourcequotas limitranges networkpolicies; do
      oc delete "$resource_type" --all -n "${VENDOR}-apps" --ignore-not-found 2>/dev/null || true
    done
    info "Workload resources removed."
  fi
fi

info "Removing namespace ${VENDOR}-apps..."
info "Note: You may see 'namespace deleted' from the API — this is normal."
info "      If the prompt does not return, press Ctrl-C and check namespace status."
if [[ "$DRY_RUN" == true ]]; then
  echo "    [DRY RUN] would delete namespace ${VENDOR}-apps"
else
  # Strip known finalizers before deletion to prevent hanging
  info "Removing namespace finalizers..."
  oc patch namespace "${VENDOR}-apps" --type=json     -p='[{"op":"remove","path":"/metadata/finalizers"}]' &>/dev/null 2>&1 || true

  oc delete namespace "${VENDOR}-apps" --ignore-not-found

  # Wait for namespace to terminate, force-remove if still stuck
  info "Waiting for namespace to terminate..."
  WAIT_SECS=0
  MAX_WAIT=60
  while oc get namespace "${VENDOR}-apps" &>/dev/null 2>&1; do
    if [[ $WAIT_SECS -ge $MAX_WAIT ]]; then
      info "Namespace stuck in Terminating — force-removing via finalize API..."
      oc get namespace "${VENDOR}-apps" -o json         | jq '.spec.finalizers = []'         | oc replace --raw /api/v1/namespaces/${VENDOR}-apps/finalize -f -
      break
    fi
    echo "    ... still terminating (${WAIT_SECS}s elapsed)"
    sleep 5
    WAIT_SECS=$((WAIT_SECS + 5))
  done
  info "Namespace ${VENDOR}-apps removed."
fi

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
