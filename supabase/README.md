# B Fresas Lovers — Supabase

This directory is the versioned Supabase layer for the B Fresas Lovers app.

## Architecture

- **Supabase:** production database, authentication, storage, functions and database logic.
- **GitHub:** source control for the app and Supabase migrations/configuration.
- **Netlify:** publishes the frontend from the GitHub repository.

## Project

- Supabase project ref: `weedtysnxjqqbficwgrx`
- GitHub repository: `bfresaslovers-gif/B-Fresas-Lovers-Base-`
- Production branch: `main`

## Migration rule

Every future database/schema change must be represented by a new timestamped file under `supabase/migrations/` and committed to GitHub. Existing production data is not stored in GitHub.

Do not commit API secrets, service-role keys, database passwords, or `.env` files.

## Current state

The production Supabase database already contains the migration history created through the Supabase dashboard/MCP. The repository is being brought into alignment without deleting the current application files.
