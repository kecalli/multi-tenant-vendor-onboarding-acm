# Multi-Tenant Vendor Onboarding via ACM Policies

This repository contains the architecture and blueprints to demonstrate automated, secure, third-party vendor onboarding using Red Hat Advanced Cluster Management (ACM).

## Key Features Demonstrated:
* **Admin GUI-Driven Onboarding:** Admins can onboard tenants by editing minor configuration variables directly in the ACM console.
* **Console Customization:** Vendors are strictly isolated to ACM multi-cluster views and blocked from accessing local cluster OCP infrastructure.
* **SSO-Ready Navigation:** Injects a dynamic sidebar link directly pointing to a shared Keycloak/OIDC-authenticated Quay Registry.
* **Self-Service Application Selection:** Pre-loads approved application definitions directly inside the ACM Application wizard.
