# Curatering — mobile inquiry → web handoff

Focused handoff for porting **Inquire Catering** and **My Catering Inquiries** from the Flutter mobile app to the customer/guest webapp.

> **Zip for Cursor:** `handoff/web-inquiry-handoff.zip` (regenerate: `handoff/build-web-inquiry.ps1`).  
> Broader customer/guest package: `handoff/web-customer-full-handoff.zip`.  
> This doc is the **inquiry-only** implementation map.

## Source of truth (production)

| What | Path | Approx. lines |
|------|------|----------------|
| Inquiry wizard UI | `packages/frontend/lib/main.dart` → `InquiryScreen` | ~14963–16796 |
| Wizard progress / packages panel | `_InquiryWizardProgressBar`, `_CateringPackagesPanel` | ~14784–14961 |
| My Inquiries list | `MyInquiriesScreen` | ~16798–17400+ |
| Model + status helpers | `InquiryRecord`, `inquiryStatusReadable`, pricing consts | ~854–887, ~2132–2894 |
| Client API | `AppState.submitInquiry`, `loadInquiries`, `cancelInquiryAsCustomer`, `countCateringScheduleConflicts` | ~4007+, ~5356+, ~5883+ |
| Theme studio (optional at submit) | `lib/features/event_design/event_theme_design_screen.dart` | — |
| Allergen UI | `lib/utils/allergen_ui.dart` | — |
| Backend | `packages/backend/src/index.ts` | GET/POST inquiries, cancel, schedule-conflicts, feedback |

Ignore manager/POS catering screens (`ManagerDashboardScreen`, `/api/mobile/pos/catering/*`) when building **customer/guest** web.

---

## Who can inquire

| Role | Entry | Notes |
|------|--------|--------|
| **Guest** | `GuestCustomerShell` tab **Inquire** | Guest session email (`guest_*@guest.curatering.internal`) is sent as `user_email`; contact email is collected on the form as `inquiry_email`. “View My Inquiries” after submit prompts login. |
| **Registered customer** | Dashboard tile **Inquire Catering** / drawer | Prefills name, contact, email from profile. |

Both use the same `InquiryScreen` and `POST /api/mobile/inquiries`.

---

## Screens to implement on web

### 1. Inquire Catering (`InquiryScreen`)

4-step wizard with top progress bar:

| Step | Label | UI |
|------|--------|-----|
| 0 | Catering Packages | Tabs: **Within Taguig** / **Outside Taguig**. Copy for Catering vs Catering with Event Styling (₱500/pax, setup, styling notes). NEXT → step 1. |
| 1 | Enter number of guests | Centered numeric pax field. If **≥ 50** → auto package = Catering with Event Styling. Show base estimate `pax × ₱500`. BACK / NEXT. |
| 2 | Fill Inquiry Form | Full form (sections below). Confirm dialog → submit → step 3. |
| 3 | Completed | Success copy + summary lines. CTAs: View My Inquiries (auth) / Submit another. |

**Package rule (critical):**

- Landing pax **&lt; 50** → `inquiry_type = CATERING`, default `service_included = no` (user can still opt into styling for a surcharge).
- Landing pax **≥ 50** → `inquiry_type = CATERING WITH EVENT STYLING`, `service_included = yes`.
- Changing guest count on the form re-syncs type when crossing 50 (`_syncInquiryPackageFromGuestCount`).

Constants:

```
kMinCateringOnlyPax = 10
kMinCateringEventPax = 50          // legacy name; landing uses kInquiryLandingEventStylingMinPax
kInquiryLandingEventStylingMinPax = 50
kPesosPerPax = 500
kEventStylingSurchargePerPaxBelow50 = 500  // when styling opted-in below 50 guests
```

Legacy type string still accepted by API: `CATERING AND EVENT` → normalize to `CATERING WITH EVENT STYLING`.

### 2. My Catering Inquiries (`MyInquiriesScreen`)

4 tabs:

| Tab | Filter |
|-----|--------|
| Waiting | `isWaiting`: `submitted`, `pending`, `online_inquiries`, `online_inquiry`, `new_event` |
| Responded | Not waiting, not completed, not cancelled (pipeline: down payment / ongoing / full payment / processing, etc.) |
| Completed | `status == completed` (default date range: past 30 days) |
| Cancelled | `status == cancelled` |

List features:

- Search by transaction ref / type / event title / status
- Type filter: all / catering only / event styling
- Pull-to-refresh → `GET /api/mobile/inquiries?user_email=`
- Detail dialog (fields + theme preview if present + payment proof widgets)
- **Follow up** → `submitHelpRequest` (help/support ticket to manager)
- **Cancel** (waiting / early stages only) → `PATCH .../cancel-customer`
- **Feedback** on completed → `POST /api/mobile/order-feedback` with `kind: catering_inquiry`
- Local prefs: feedback draft + “read completed” badges (`SharedPreferences` keys `inquiry_feedback_v1_*`, `inquiry_completed_read_v1_*`)

---

## Form sections (step 2) — field checklist

### EVENT INFORMATION

| Field | Required | Notes |
|-------|----------|--------|
| Package type | display-only | From landing / guest sync |
| Event title | **Yes if** Catering with Event Styling | |
| Event type | Yes | Dropdown: Birthday, Wedding, Baptism, Corporate, Sports, Government, Social event, Reunion, Gala, Other (+ free text) |
| Customer | Yes | Checkbox “Same as contact person” |
| Formality | Yes | casual / semiformal / formal |
| Contact person | Yes | Prefill from profile |
| Contact number | Yes | Digits, max 11; server: ≥7, `[0-9+\-\s()]` |
| Email | Yes | Valid email; used as `inquiry_email` |
| Event schedule | ≥1 complete window | Date + from + to; multi-day “Add another day”; no past times; end &gt; start |
| Schedule conflicts | advisory | Debounced `POST /api/mobile/catering/schedule-conflicts` — warn if overlap with `for_processing` rows; **still allow submit** |
| Event venue | Yes | Text + Nominatim suggestions + optional map pin; coverage warning helper |
| Setting | Yes | open / closed |
| Number of guests | Yes | Min **10** |
| Pax buffer | Optional | Extra pax on estimate only (₱500 each) |
| Note | Optional | |
| Event styling radios | If catering-only | Without / With; with → surcharge below 50 |

### EVENT THEME DESIGN (only if Catering with Event Styling)

| Mode | Behavior |
|------|----------|
| **Suggest** (default) | `theme_design: { eventDesignSource: 'macrina', note, reference_images[] }` |
| **Create my own** | Opens `EventThemeDesignScreen` (`persistToOrder: false`); payload returned into `theme_design` |

Seating layout is **manager-only** on mobile (`InquiryRecord.canShowSeating = false`). Optional `seating_plan` on POST is supported by API but **not** collected on customer inquire UI — do not block web MVP on seating.

### ALLERGENS

Multi-select from catalog (`loadAllergenCatalog`) + “Others” text. Stored in submit payload as `guest_allergens`; dishes conflicting with allergens are blocked from selection.

### MENU

| Choice | Behavior |
|--------|----------|
| Curate own | Set menu dropdown (or All Dishes); pick **4–8** dishes; optional food tasting date/time; search; allergen filtering; menu modification extras computed client-side |
| Suggest a menu | Sets `menu_suggestion_note = 'No, suggest me a menu instead.'`; no dish picks required |

### SUMMARY / SUBMIT

Live estimate lines:

1. Base food cost = guests × 500  
2. Pax buffer × 500  
3. Menu modifications (if any)  
4. Event styling surcharge (if opted-in and guests &lt; 50)

Confirm dialog → loading → `submitInquiry` → success step.

---

## POST body contract (`POST /api/mobile/inquiries`)

Always merge `user_email` (session) on the client.

```json
{
  "user_email": "customer@or.guest.session",
  "inquiry_type": "CATERING" | "CATERING WITH EVENT STYLING",
  "event_title": "",
  "event_type": "Birthday",
  "customer": "",
  "contact_person": "",
  "contact_number": "",
  "inquiry_email": "",
  "date_of_event": "[{\"date\":\"YYYY-MM-DD\",\"from\":\"HH:MM\",\"to\":\"HH:MM\",\"label\":\"...\"}]",
  "note": "",
  "curate_own_menu": true,
  "selected_set_menu": "All Dishes",
  "selected_dishes": ["Dish A", "Dish B"],
  "include_event_theme": false,
  "guest_count": 20,
  "pax_buffer": 0,
  "estimated_total": 10000,
  "cost_breakdown": [{ "label": "Base food cost", "amount": 10000 }],
  "menu_modifications": { "...": "optional InquiryMenuModifications JSON" },
  "menu_suggestion_note": "",
  "theme_suggestion_note": "",
  "theme_design": {},
  "event_city": "",
  "event_setting": "open",
  "service_included": "yes" | "no",
  "formality_level": "casual",
  "guest_allergens": [],
  "food_tasting_requested": false,
  "food_tasting_date": "",
  "food_tasting_time": ""
}
```

**Server behavior:**

- Catering-only → insert `catering_orders` (`order_type: catering`, status `online_inquiries`, source `online_inquiry`)
- With event styling → insert `event_orders` (`order_type: catering_event`, theme_design + seating_plan JSON)
- Response `201`: `{ id, inquiry_no }` where `inquiry_no = INQ-{first8 of uuid}`
- Confirmation email to `user_email`

**Server validations (mirror on web for UX):** contact, phone, email, venue, min guests 10, event_type, schedule slots with date/from/to, event_title if styling package, food tasting fields if requested, ≥1 dish if `curate_own_menu` (server says ≥1; **client requires 4–8** — keep client rule stricter).

---

## Other APIs used by inquiry UX

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/mobile/menu` | Catering dishes |
| GET | `/api/mobile/set-menus` | Set menu presets |
| GET | `/api/mobile/allergens` | Allergen catalog |
| GET | `/api/mobile/inquiries?user_email=` | List (union catering + event) |
| POST | `/api/mobile/inquiries` | Create |
| PATCH | `/api/mobile/inquiries/:id/cancel-customer` | Cancel if status in `new_event`, `online_inquiries`, `for_processing` |
| POST | `/api/mobile/catering/schedule-conflicts` | Body `{ windows: [{date,from,to}] }` → `{ conflict_window_count, has_conflict }` |
| POST | `/api/mobile/order-feedback` | Completed inquiry feedback (`kind: catering_inquiry`, `reference: id`) |
| POST | `/api/public/events/theme-design/*` | Theme studio (create-own path only) |
| Help/follow-up | existing help-request endpoint used by `submitHelpRequest` | Manager notify |

Supporting loads: profile, realtime inquiry delta reload (optional on web).

---

## Status display map

| DB / pipeline status | Customer label |
|----------------------|----------------|
| `new_event` | New Event |
| `online_inquiries` | Online Inquiries |
| `for_down_payment` | For Down Payment |
| `for_ongoing` / `for_processing` | On Going |
| `for_full_payment` | For Full Payment |
| `completed` | Completed |
| `cancelled` | Cancelled |

Loyalty: on completed, `floor(total_cost / step) * points` from API field `loyalty_points_earned`.

---

## Web implementation checklist (suggested order)

### MVP UI (parity with mobile happy path)

1. [ ] Routes: `/inquire`, `/my-inquiries` (guest tab + logged-in dashboard)
2. [ ] Wizard shell + progress (4 steps)
3. [ ] Packages copy (Taguig / Outside tabs)
4. [ ] Guest count landing + package auto-switch at 50
5. [ ] Event information form + validation
6. [ ] Multi-slot schedule pickers + conflict advisory
7. [ ] Venue text (map pin can follow)
8. [ ] Allergens + menu curate/suggest (4–8 dishes)
9. [ ] Cost estimate + confirm + POST
10. [ ] Success screen
11. [ ] My Inquiries tabs + detail + cancel + follow-up + feedback

### Often missing / easy to skip (mobile has them)

- [ ] Event styling opt-in **below 50** with ₱500/pax surcharge line
- [ ] Menu modification charges from set-menu add/remove/replace
- [ ] Theme “Suggest” vs “Create my own” + reference images / theme studio
- [ ] Food tasting schedule when curating own menu
- [ ] Schedule conflict warning (non-blocking)
- [ ] Coverage / out-of-area venue warning
- [ ] Completed-tab past-30 filter + unread badges
- [ ] Payment proof images in inquiry detail (after manager records payments)
- [ ] Guest: after submit, gate “View My Inquiries” behind auth
- [ ] Prefill profile fields for registered users

### Out of scope for customer web (staff)

- Manager online-inquiries queue, stage moves, type switch between catering/event tables
- Customer seating editor

---

## Related modules to copy / port

From `packages/frontend/lib/`:

- `features/event_design/*` — only if implementing “Create my own” theme
- `utils/allergen_ui.dart` — allergen multi-select behavior
- `utils/order_type_utils.dart` — catering/event type helpers
- Pricing / `InquiryMenuModifications` / `computeInquiryMenuModifications` in `main.dart`

From `packages/backend/src/index.ts`: reuse existing mobile routes; no new schema required for basic inquire + list + cancel.

---

## Smoke test plan

1. Guest: Inquire → pax 20 → catering form → suggest menu → submit → 201 + email path.
2. Guest: pax 55 → event styling form → event title required → submit → row in `event_orders`.
3. Registered: inquire with curate 4–8 dishes + allergens → list appears under Waiting.
4. Cancel while `online_inquiries` → Cancelled tab; cancel after later stage → API 400.
5. Opt-in styling at 30 guests → estimate includes styling surcharge.
6. Schedule overlapping a `for_processing` event → warning shown, submit still works.
7. Completed inquiry → feedback stars/remarks persist.

---

## Regenerating full customer zip (includes inquiry)

```powershell
powershell -ExecutionPolicy Bypass -File handoff/build-web-customer-full.ps1
```

This inquiry doc lives in `handoff/web-inquiry-docs/` and is intended to travel with the webapp implementation work even when the full zip is not unpacked.
