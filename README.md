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
To demonstrate zero-touch provisioning, log in via a private browser window as the newly created vendor to witness the automated cross-console interface updates:

1. Navigate to the cluster console and select the **OIDC/SSO Login Option**. Log in using `vendor-a-user`.
2. OpenShift validates the token string against the IdP, dynamically generates the shadow user, and maps them to the pre-staged RBAC policy—instantly isolating them to their sandbox namespace.
3. **The Multi-Cluster Console Payoff:** When the user accesses the **RHACM Hub Console**, they can look at the global utility header in the top-right corner and click the **Application Launcher grid icon (9-dot menu)**.
4. Drop down the menu to see a dedicated section titled **"Vendor Developer Tools"** with a direct, branded link labeled **"Vendor A Quay Registry"**.
5. The vendor clicks the shortcut. Red Hat Quay intercepts the login redirect, runs a silent OIDC handshake with the same central IdP, and leverages **Just-In-Time (JIT) provisioning** to dynamically auto-create their Quay user profile and private organization 
repository space (`/vendor-a`) on the fly.

### Phase 4: Self-Service Application Deployment (The Workload Story)
Once the identity and infrastructure are established, showcase how the vendor can independently deploy authorized multi-cluster software workloads using ACM's GitOps subscription model:

Switch to or stay logged in as vendor-a-user inside the ACM Hub Console.

Navigate to Applications and click the blue Create application button in the top right.

Under the Repository Type (Source) selection field, select Git from the dropdown menu.

Use the pre-configured subscription channels to point ACM to this repository. The user sets the path field to target the /example-vendor-applications directory.

In the Destination field, the vendor enters their assigned sandbox namespace (vendor-a-apps).

Click Save in the top right.

The Application Topology Payoff: ACM instantly maps the Git repository and generates a live, interactive Topology Map on the screen. The vendor can watch in real-time as the subscription channel pulls sample-workload-manifest.yaml out of Git, verifies permissions, and spins up the application pods within their isolated namespace boundaries.
