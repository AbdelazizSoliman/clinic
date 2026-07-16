# Backup and restore runbook

Provider backups are not assumed to exist. Before launch, enable encrypted daily
PostgreSQL backups, at least 30 days retention, and point-in-time recovery where
the selected plan supports it. Enable private object-storage encryption and
versioning with a lifecycle policy approved by the business/legal owner.

For restoration: declare an incident and maintenance window; preserve logs;
restore the database to an isolated production-class database; restore or roll
back object versions; set new connection credentials; run `bin/rails db:prepare`;
verify integrity checks, attachment access, order snapshots, queue state, and a
sample checkout; then reopen traffic. Record timestamps and evidence. Never copy
prescriptions or other real medical data into development.

Initial planning assumptions are RPO 24 hours without PITR (target 15 minutes
with PITR) and RTO four hours. The production owner must approve achievable
values and test restoration quarterly.
