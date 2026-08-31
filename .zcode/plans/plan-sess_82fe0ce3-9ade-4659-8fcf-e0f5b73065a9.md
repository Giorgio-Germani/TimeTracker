# Plan: Reliable idle handling — keep running + flag for review

## Problem
When idle grace expires with no response, the server silently stops the timer backdated to last activity. Notification channels are all conditional (Web Push only if subscribed, Socket.IO only with tab open, extension/mobile only via polling), so the user can miss everything and end up with a truncated entry.

## New behavior (core change)

**The timer is never silently stopped.** After the grace period expires with no response:

1. Server marks the time entry as `needs_review` (new column, e.g. `idle_flagged_at` on `TimeEntry`) and **keeps the timer running**.
2. All clients see this in timer status (`needs_review: true`) and surfaces a prominent banner: "We couldn't reach you while you were idle — this entry needs review."
3. Optional safety cap (setting, default generous/off): auto-stop only after N hours unreviewed.

The existing two-stage flow stays: stale heartbeat → `idle_notified_at` + notifications; grace expires → flag instead of stop. Any heartbeat still clears the pending state.

## Notification channels (deliver everywhere possible)

- **Web — Web Push becomes the primary channel.** When a timer is started from the web without an active push subscription, prompt to enable notifications (permission + `/api/push/subscribe`). Service worker (`sw.js`) handles the `idle` push with "I'm working" / "Stop" actions. VAPID keys must be configured (surface a clear admin warning if not).
- **Socket.IO — demoted to in-tab prompt only** (interactive Yes/Trim/No when the tab is open). Not relied upon for delivery.
- **Browser extension** — keeps polling `idle_notified` via `chrome.alarms`; verify detection interval and notification permission; shows `chrome.notifications` with actions.
- **Desktop (Electron)** — unchanged: local `powerMonitor` idle detection + critical notification; also honors `idle_notified`/`needs_review` from status polling.
- **Mobile (polling only, per your choice)** — foreground tick shows the "Still working?" notification with action buttons when `idle_notified` is set; on app open, if a pending idle flag or `needs_review` entry exists, show a full-screen banner immediately (catch-up). WorkManager periodic polling stays as-is. No FCM.

## Review UX

- Web: a "Needs review" indicator on the dashboard + filtered list of flagged entries. Resolution actions: **Trim to last activity** (sets end = last heartbeat + idle timeout, stops timer), **Keep as-is** (stop timer at now / at your chosen end), or **Edit** end time manually.
- Extension/mobile: banner on open that deep-links to the review UI.
- Notifications page in settings showing per-device delivery health: last heartbeat per client, push subscription status, so a silent-channel failure is visible before it costs you data.

## Files touched (roughly)

- Server: `app/models/time_entry.py` (flag columns), `app/utils/scheduled_tasks.py` (`check_idle_timers` → flag instead of stop, keep push emit), `app/routes/api.py` + `api_v1_time_entries.py` (expose `needs_review`, resolve endpoint), `app/routes/push_notifications.py` (status), settings.
- Web: `app/static/idle.js`, `pwa-enhancements.js`, `sw.js`, dashboard templates for review UI + onboarding prompt.
- Extension: `browser-extension/background.js` (handle `needs_review`).
- Desktop: `desktop/src/main/idle.js` (stop auto-stop, show review banner).
- Mobile: `idle_detection_service.dart`, `foreground_task_handler.dart`, review banner UI.

## What we are NOT doing
- Not removing auto-credited stop entirely as a *user action* — trimming to last activity remains a one-click resolution; it just stops being the automatic outcome.
- Not adding FCM.
