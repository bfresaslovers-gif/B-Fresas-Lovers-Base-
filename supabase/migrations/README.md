# Supabase migrations

Migration files in this directory are the versioned database history used by Supabase GitHub Integration.

The production project currently has migrations through:

`20261006173608_contabilidad_receipts_payment_method_and_monthly_summary`

The next step is to import/reconcile the existing production migration SQL into this directory rather than inventing or rewriting historical migrations. This keeps the database history and Git history consistent.

Do not delete or reorder migration history. New changes get a new timestamped migration.
