# Curatering

Flutter app + Postgres backend for authentication and Super Admin features.

## Backend (Postgres + API)

1. Open the `server/` folder.
2. Copy `server/.env.example` to `server/.env` and set:
   - `DATABASE_URL` (your Postgres connection string)
   - `JWT_SECRET`
   - `SEED_SUPER_ADMIN_EMAIL` and `SEED_SUPER_ADMIN_PASSWORD` (for first-time login)
3. Install dependencies:
   - `npm install`
4. Start the API:
   - `npm run start`

On startup, the server creates the required tables (`users`, `help_requests`, `notifications`, `action_logs`) if they don't exist yet.

## Flutter configuration

The app calls the backend at `https://ffgifzwwqdjeyyedaciu.supabase.co/rest/v1/` by default.

If your backend runs on a different URL/port, start the app with:

- `flutter run --dart-define=API_BASE_URL=https://ffgifzwwqdjeyyedaciu.supabase.co/rest/v1/`

Then login using your seeded Super Admin credentials to access:
- `Manage Accounts`
- `Help Requests`
- `Action Logs`
