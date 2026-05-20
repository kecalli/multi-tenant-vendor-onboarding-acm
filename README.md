# Multi-Tenant Vendor Onboarding via ACM Policies

This repository contains the architecture and blueprints to demonstrate automated, secure, third-party vendor onboarding using Red Hat Advanced Cluster Management (ACM) integrated with an enterprise Single Sign-On (SSO) identity plane.

## Key Features Demonstrated:
* **Identity Provider (IdP) as Source of Truth:** Onboarding begins at the central authentication layer (e.g., Keycloak, Okta, Azure AD), enforcing enterprise governance across all platform tools.
* **Admin GUI-Driven Access Prep:** Platforms engineers prepare cluster permissions by executing a global find-and-replace on a single template string entirely within the ACM browser window.
* **Just-In-Time (JIT) Registry Provisioning:** Eliminates manual image registry setup; the vendor's dedicated Quay organization and user profile are automatically generated upon their first SSO login handshake.
* **Strict Tenant Console Isolation:** Customizes navigation shortcuts for external users, routing them strictly to their multi-cluster perspectives while removing default OpenShift infrastructure viewpoints.

---

## Repository Architecture

The repository remains flat, lightweight, and optimized for a clean, zero-copy-paste live demonstration flow:

```text
multi-tenant-vendor-onboarding-acm/
├── README.md                            # Documentation and Live Demo Script
├── 1-master-onboarding-policy.yaml      # Reusable Blueprint Policy (Dormant Template)
└── example-vendor-applications/         # Isolated application subfolder for vendor self-service
    ├── app-subscription-channel.yaml    # Pre-configured ACM Git Channel blueprint
    └── sample-workload-manifest.yaml    # Example workload template selectable via dropdown wizard
```

---

## Operational Workflows

### Phase 1: Onboarding the Identity (IdP Control Plane)
To establish a single corporate identity across ACM, OpenShift, and Quay, the vendor profile is generated at the centralized authentication layer first:

1. Open your corporate Identity Provider dashboard (e.g., Keycloak).
2. Create a new user identity matching the target vendor naming convention (e.g., `vendor-a-user`).
3. Set a temporary credential. This user account is now instantly globally authorized via OIDC/OAuth.

### Phase 2: Pre-Staging Cluster Access (Admin GUI Steps)
With the central identity established, the platform administrator prepares the target environment boundaries inside the ACM console:

1. Navigate to **Governance** ➔ **Policies** inside the ACM console and select the dormant `template-onboard-vendor` blueprint.
2. Click **Edit YAML** to open the embedded browser code editor.
3. Press **`Ctrl + F`** (or `Cmd + F` on Mac) to bring up the inline search-and-replace panel.
4. Input the following configuration tokens:
   * **Search For:** `generic-vendor`
   * **Replace With:** `vendor-a` *(or your target partner name, e.g., `alpha`, `beta`)*
5. Click the **Global Replace All** icon (the stacked `ab` over `ab` icon on the far right of the replace input text box).
6. Click the blue **Save** button.

ACM processes this as a standalone policy instantiation. The governance engine instantly deploys an isolated namespace (`vendor-a-apps`) and plants a `RoleBinding` waiting to map to the exact string passed by the IdP token upon first login.

### Phase 3: First-Time Login & JIT Payoff (Tenant Experience)
To demonstrate zero-touch provisioning, log in via a private browser window as the newly created vendor:

1. Navigate to the cluster console and select the **OIDC/SSO Login Option**. Log in using `vendor-a-user`.
2. OpenShift validates the token string against the IdP, dynamically generates the shadow user, and maps them to the pre-staged RBAC policy—instantly isolating them to their sandbox namespace.
3. Locate the custom **"Vendor Tools"** section in the navigation sidebar and click the **"vendor-a Registry"** shortcut link.
4. Red Hat Quay intercepts the login, runs a silent handshake with the IdP, and leverages **Just-In-Time (JIT) provisioning** to dynamically auto-create their Quay user profile and private vendor image repository space on the fly.
