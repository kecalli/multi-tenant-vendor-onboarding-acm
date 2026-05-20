# Multi-Tenant Vendor Onboarding via ACM Policies

This repository contains the architecture and blueprints to demonstrate automated, secure, third-party vendor onboarding using Red Hat Advanced Cluster Management (ACM).

## Key Features Demonstrated:
* **Admin GUI-Driven Onboarding:** Admins can onboard tenants by editing minor configuration variables directly in the ACM console.
* **Console Customization:** Vendors are strictly isolated to ACM multi-cluster views and blocked from accessing local cluster OCP infrastructure.
* **SSO-Ready Navigation:** Injects a dynamic sidebar link directly pointing to a shared Keycloak/OIDC-authenticated Quay Registry.
* **Self-Service Application Selection:** Pre-loads approved application definitions directly inside the ACM Application wizard.

## Operational Workflows

### Onboarding a New Vendor (Admin GUI Steps)
To onboard a new partner vendor entirely within the ACM GUI:

1. Copy the layout template inside `2-vendor-config-template.yaml`.
2. In the ACM Console, click the **Plus (+)** icon in the top right to import YAML.
3. Replace the placeholder variables with your specific vendor's settings:
   * **name:** A short lowercase ID for system naming hooks (e.g., `alpha`).
   * **displayName:** The clean title that shows in the navigation bar menu.
   * **namespace:** The isolated sandbox project namespace assigned to them.
4. Click **Create/Save**. ACM's backend policy engine will instantly build the environment.

### Swapping Vendors for Live Demonstrations
To quickly switch the tenant configuration during a live presentation without creating code clutter:
1. Locate the `vendor-config` ConfigMap in the ACM Search box.
2. Click **Edit YAML** inside the browser window.
3. Modify the data fields inline from your first vendor setup to your second vendor setup.
4. Click **Save**. ACM will automatically clean up the old routes and reconcile the new vendor workspace within seconds.
