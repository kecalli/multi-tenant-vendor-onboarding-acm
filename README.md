Multi-Tenant Vendor Onboarding via ACM Policies
This repository contains the architecture and blueprints to demonstrate automated, secure, third-party vendor onboarding using Red Hat Advanced Cluster Management (ACM) integrated with an enterprise Single Sign-On (SSO) identity plane.
Key Features Demonstrated
Identity Provider (IdP) as Source of Truth: Onboarding begins at the central authentication layer (e.g., Keycloak, Okta, Azure AD), enforcing enterprise governance across all platform tools.
Script-Driven Vendor Onboarding: Platform engineers onboard a new vendor by running a single shell script. No manual YAML editing or copy-paste required.
Policy-Enforced Tenant Isolation: Each vendor receives an isolated namespace with scoped RBAC, resource quotas, and network policies enforced continuously by ACM governance.
Just-In-Time (JIT) Registry Provisioning: Eliminates manual image registry setup; the vendor's dedicated Quay organization and user profile are automatically generated upon their first SSO login handshake.
ACM-Only Vendor Experience: Vendors interact exclusively through the ACM hub console. OpenShift infrastructure perspectives are hidden, routing external users strictly to their application sandbox.
Pre-Wired Self-Service App Catalog: Approved sample workloads are automatically deployed and visible to the vendor in the ACM Applications topology view on first login — no manual app creation steps required.
---
Repository Architecture
```
multi-tenant-vendor-onboarding-acm/
├── README.md
├── onboard-vendor.sh                         # Vendor onboarding script (run once per vendor)
├── 0-platform-console-policy.yaml           # One-time platform policy (apply before first vendor)
├── 1-master-onboarding-policy.yaml          # Per-vendor policy template (rendered by script)
└── example-vendor-applications/
    ├── 0-vendor-app-channel.yaml            # One-time Git channel (apply before first vendor)
    ├── 1-vendor-sample-app-subscription.yaml  # Per-vendor app subscription (rendered by script)
    └── workloads/
        └── sample-workload-manifest.yaml    # Static workload manifests pulled by subscription
```
File Roles
File	Who applies it	When
`0-platform-console-policy.yaml`	Platform admin	Once, before first vendor onboarded
`example-vendor-applications/0-vendor-app-channel.yaml`	Platform admin	Once, before first vendor onboarded
`onboard-vendor.sh`	Platform admin	Once per vendor
`1-master-onboarding-policy.yaml`	Rendered and applied by `onboard-vendor.sh`	Per vendor
`example-vendor-applications/1-vendor-sample-app-subscription.yaml`	Rendered and applied by `onboard-vendor.sh`	Per vendor
`example-vendor-applications/workloads/sample-workload-manifest.yaml`	Pulled from Git by ACM subscription	Automatically
---
Prerequisites
Red Hat OpenShift cluster with ACM hub installed
`oc` CLI installed and logged in as a cluster admin
An Identity Provider (IdP) configured in OpenShift (Keycloak, Okta, Azure AD, etc.)
Red Hat Quay configured with JIT provisioning against the same IdP (for Phase 3)
---
One-Time Platform Setup
These steps are performed once by a platform administrator before any vendors are onboarded.
1. Apply the platform console policy
This policy hides the OpenShift admin and developer perspectives from vendor users cluster-wide. It manages the `Console` singleton CR and must live outside per-vendor policies to avoid conflicts.
```bash
oc apply -f 0-platform-console-policy.yaml
```
2. Apply the vendor app channel
This creates the ACM `Channel` that points at this Git repository. All vendor app subscriptions reference this channel.
```bash
oc apply -f example-vendor-applications/0-vendor-app-channel.yaml
```
---
Operational Workflows
Phase 1: Onboarding the Identity (IdP Control Plane)
To establish a single corporate identity across ACM, OpenShift, and Quay, the vendor profile is created at the centralized authentication layer first:
Open your corporate Identity Provider dashboard (e.g., Keycloak).
Create a new user identity matching the vendor naming convention (e.g., `vendor-a-user`).
Set a temporary credential. This user is now globally authorized via OIDC/OAuth across all connected platforms.
Phase 2: Onboarding the Vendor (Platform Admin)
With the identity established, the platform administrator runs the onboarding script. This replaces all manual YAML editing and applies both the ACM governance policy and the sample app subscription in a single step.
```bash
# Preview what will be applied without touching the cluster
./onboard-vendor.sh --vendor vendor-a --dry-run

# Onboard the vendor
./onboard-vendor.sh --vendor vendor-a
```
The script accepts the following options:
Option	Description	Default
`--vendor`	Vendor identifier, lowercase with hyphens (required)	—
`--quay-host`	Quay server hostname	`quay-server.apps.platform-customer.com`
`--dry-run`	Print rendered YAML only, do not apply	—
`--output <file>`	Write rendered YAML to file instead of applying	—
`--template <file>`	Path to policy template file	`1-master-onboarding-policy.yaml`
What the script provisions:
Isolated namespace (`vendor-a-apps`) with tenant labels
`RoleBinding` scoping `vendor-a-user` to `admin` within that namespace only
`ResourceQuota` capping CPU, memory, pods, services, storage
`LimitRange` setting default container-level resource requests and limits
`NetworkPolicy` set: default-deny ingress/egress, allow intra-namespace, allow DNS, allow OpenShift router ingress
`ConsoleLink` injecting a Quay registry shortcut into the ACM 9-dot application launcher
ACM `Application` and `Subscription` pre-wiring the approved sample workload catalog into the vendor namespace
> **Note:** The vendor user does not need to exist in OpenShift before this step. For SSO/OIDC users, OpenShift creates the shadow user automatically on first login. The `RoleBinding` waits and maps on that first login event.
Phase 3: First-Time Login & JIT Payoff (Vendor Experience)
Log in via a private browser window as the newly created vendor user:
Navigate to the ACM hub console URL and select the SSO login option. Log in as `vendor-a-user`.
OpenShift validates the token against the IdP, creates the shadow user, and maps them to the pre-staged `RoleBinding` — isolating them to their sandbox namespace instantly.
In the ACM hub console, click the application launcher grid icon (9-dot menu) in the top-right header.
A dedicated "Vendor Developer Tools" section appears with a branded "vendor-a Registry" shortcut link.
Clicking the shortcut triggers a silent OIDC handshake with Quay. Quay's JIT provisioning automatically creates the vendor's user profile and private organization (`/vendor-a`) on the fly — no manual registry setup required.
Phase 4: Self-Service Application Deployment (Vendor Experience)
The sample workload is already deployed and waiting when the vendor first logs in:
In the ACM hub console, navigate to Applications.
The `vendor-a-sample-app` application is already present, pre-wired by the onboarding script.
Click the application to open the Topology view. The vendor sees a live, interactive graph showing their `ConfigMap`, `Deployment`, `Service`, and `Route` — all running within their isolated namespace.
The `Route` provides a directly accessible URL the vendor can use to verify their workload is live.
The vendor does not need to configure channels, set paths, or fill in destination namespaces. Everything is pre-staged and governed by ACM policy.
---
Tenant Isolation Summary
Each onboarded vendor receives the following isolation guarantees, enforced continuously by ACM:
Control	Mechanism	Scope
Namespace isolation	`Namespace` CR	Per vendor
Access control	`RoleBinding` → `admin` ClusterRole	Vendor namespace only
Resource limits	`ResourceQuota` + `LimitRange`	Vendor namespace
Network isolation	`NetworkPolicy` default-deny + selective allow	Vendor namespace
Console isolation	`Console` CR perspective restriction	Cluster-wide (platform policy)
Registry shortcut	`ConsoleLink`	Per vendor
---
ClusterSet Readiness
The `Placement` in `1-master-onboarding-policy.yaml` currently targets `local-cluster` for single-cluster lab use. When you are ready to adopt ClusterSets:
Add a `clusterSets` field to the `Placement` spec referencing your ClusterSet name
Label your managed clusters accordingly
No other changes to the policy or onboarding script are required.
---
Future Enhancements
Red Hat Developer Hub integration: Replace the shell script with a Backstage Software Template for a full multi-step wizard UI, Git-native rendering, and audit trail
AAP Survey integration: Wrap the onboarding script in an Ansible Job Template with a Survey for a form-driven UI without requiring Developer Hub
Offboarding script: Mirror of `onboard-vendor.sh` to cleanly remove a vendor's policy, namespace, and all associated resources
Additional approved workloads: Add more manifests under `example-vendor-applications/workloads/` to expand the vendor's self-service catalog
