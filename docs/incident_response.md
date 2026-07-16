# Incident response basics

1. Appoint an incident owner, enable maintenance mode if integrity/privacy is at
   risk, pause workers if jobs can worsen the incident, and preserve logs.
2. Disable registration in pharmacy settings. Deactivate compromised staff and
   use **revoke all sessions**. Inspect security events without exporting medical
   data.
3. Rotate database, mail, storage, Rails/encryption, and error-reporting secrets
   according to exposure; restarting all processes is required after rotation.
4. For malware, deny the object, preserve only the minimum forensic evidence,
   notify an administrator, and do not download it to unmanaged workstations.
5. For database/storage outage, keep maintenance mode active, restore from the
   tested backup procedure, verify integrity, then perform smoke tests.
6. Communicate using order public numbers and safe IDs—never prescriptions,
   addresses, credentials, or medical notes.

This runbook is technical guidance, not a compliance certification.
