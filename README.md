# Multi-Tenant Vendor Onboarding via ACM Policies
This repository contains the architecture and blueprints to demonstrate automated, secure, third-party vendor onboarding using Red Hat Advanced Cluster Management (ACM).

## Key Features Demonstrated:

* Admin GUI-Driven Onboarding: Admins can onboard tenants by executing a global find-and-replace on a single template string entirely within the ACM browser window.
* Console Customization: Injects an isolated sidebar navigation shortcut that maps directly to the vendor's dedicated toolsets.
* Strict Tenant Isolation: Restricts vendor visibility entirely to assigned ACM multi-cluster perspectives while removing default OpenShift administrative and developer viewpoints.
* Self-Service Catalog Integration: Pre-loads pre-approved application blueprints directly inside the ACM Application creation dropdown wizard.

## Repository Architecture

The repository is structured to remain flat, lightweight, and optimized for a zero-copy-paste live demonstration:

```text
multi-tenant-vendor-onboarding-acm/
├── README.md                            # Documentation and Live Demo Script
├── 1-master-onboarding-policy.yaml      # Reusable Blueprint Policy (Dormant Template)
└── example-vendor-applications/         # Isolated application subfolder for vendor self-service
    ├── app-subscription-channel.yaml    # Pre-configured ACM Git Channel blueprint
    └── sample-workload-manifest.yaml    # Example workload template selectable via dropdown wizard


Operational Workflows
Onboarding a New Vendor (Admin GUI Steps)
To onboard a new partner vendor using our universal blueprint:

Navigate to Governance ➔ Policies inside the ACM console and select the dormant template-onboard-vendor blueprint.

Click Edit YAML to open the embedded browser code editor.

Press Ctrl + F (or Cmd + F on Mac) to bring up the inline search-and-replace panel.

Input the following configuration tokens:

Search For: generic-vendor

Replace With: vendor-a (or your target partner name, e.g., alpha, beta)

Click the Global Replace All icon (the stacked ab over ab icon on the far right of the replace input text box).

Click the blue Save button.

ACM automatically handles this as a unique, standalone policy instantiation. The governance engine will instantly spin up a dedicated namespace, attach targeted tenant RBAC parameters, and generate the custom OpenShift console shortcuts.

Swapping Vendors for Live Demonstrations
To showcase the rapid lifecycle management capabilities of the platform during a live presentation:

Return to the Governance dashboard and open the freshly created policy-onboard-vendor-a.

Click Edit YAML and press Ctrl + F to open the replace tool.

Run a global swap replacing your active vendor string with your second demonstration profile:

Search For: vendor-a

Replace With: vendor-b

Click Replace All and select Save.

The underlying platform engine will immediately run an automated garbage-collection routine to dismantle the old routing pathways, re-evaluate the object properties, and establish the newly declared vendor environment within seconds.
