# How to use this zip in Cursor (webapp)

1. Unzip next to (or attach into) your webapp workspace.
2. Open `README.md` first â€” that is the implementation map.
3. Port UI/logic from `frontend/lib/main.dart`:
   - `InquiryScreen` (~line 14963)
   - `MyInquiriesScreen` (~line 16798)
   - pricing consts / `InquiryRecord` (~lines 854â€“2894)
4. Match API contracts in `backend/src/index.ts` (GET/POST `/api/mobile/inquiries`, cancel, schedule-conflicts, order-feedback).
5. Theme "Create my own" needs `frontend/lib/features/event_design/` + public theme-design routes.
6. Ignore manager/POS catering UI and `/api/mobile/pos/*`.

Regenerate: `powershell -ExecutionPolicy Bypass -File handoff/build-web-inquiry.ps1`
