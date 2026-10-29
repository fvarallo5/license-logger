# Phase 4 — Packages & Pay

- Packages catalog CRUD (desk)
- Pay page: invoice list + record payment
- Nav gated by `perms.viewBilling`
- Migration `_NOT_APPLIED_pay_packages_lockdown.sql`: assign/record RPCs, package_catalog_desk view, hourly_rate column revoke + member_hourly_rate RPC

**Open decisions:** card processor (Stripe/Square/manual-only) — default is manual record payment; QBO remains sync path.
