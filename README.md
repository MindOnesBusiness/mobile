# MOB Vault — mobile.mindonesbusiness.com

The member app for MindOnesBusiness: short guides on the Shelf, a private Shadow Journal, the VIP Lounge (with a link to Trick Talk), and member profiles. Free to start. VIP is $7 a month.

## Update 16: the MOB Toolshed (all-in-one), how to put it live

1. In Supabase, open **SQL Editor**, paste all of `supabase-update-16.sql`, and tap **Run**. It includes updates 12 to 15, so it works whether or not you ran 15. It is safe to run more than once. If anything fails, nothing changes.
2. Upload `index.html`, `sw.js` and `README.md` to GitHub. (`sw.js` is now `mobvault-v33`, so phones pick up the update.)

**Formidable Routine, revamped:**
- **School Hour** (30 min, right after Enterprise Hour) and **Qigong** (5 min, right before the dog walk) are new steps. They start off. Turn them on in **Edit my morning → Add one of ours**. School Hour lists today's Sticks School sessions and checks itself off once they are logged.
- **Reading goal** (Settings): track chapters read in the morning (under Fuel + Word) and at night (under Scripture & Spirit). Pick chapters a day (default 3) and the day you want to be caught up (default Sunday). A pace line says "On pace" or "Catch up X chapters by Sunday."
- **The Formidable Evening** (60 min): Wind-down & Reset 10, Evening Journaling 15 (with the 5 questions), Affirmations + Review 5, Scripture & Spirit 15, Meditation 15, then Lights out. The night-before prep list stays.
- **Sleep** (Settings): 6 to 8 hours (default 6.5). Lights out counts back from your wake time.
- **Mood check-in:** inside the evening, or tap **Mood check-in** at the top any time. Pick a mood (1 to 5), tap any feelings from the Inner Wheel, and add one line if you want. It has its own streak. Settings can add a quick mood tap to the morning too.
- **Week tab** (was History): mornings, evenings and check-ins out of 7, average mood, top 3 feelings, and scoreboard totals, for everyone. VIPs also get streaks, the last 30 days, and week-by-week numbers.

**Weekly Wheel** (`#/tools/wheel`, new): Your week first, then the Wheel of Life (8 areas, 1 to 10, wheel chart, change from last week, a mood hint next to Emotional Health), then the Inner Wheel (15 themes, 0 to 4), then priorities and one goal per area. Last week's goals get checkboxes. After 3+ check-ins in a week, the Inner Wheel fills itself in from the daily check-ins (with 7 check-ins: 0 days = 0, 1–2 = 1, 3 = 2, 4–5 = 3, 6–7 = 4). Change any score; changed ones get a dot. **Life score** = the average of the 8 areas. **Peace score** = (higher themes + 32 − wounds) ÷ 60 × 10, shown once all 15 are scored. Both match the Wheel of Life Google Sheet. VIP only beyond the Wheel of Life (see below).

**Sticks School** (`#/tools/school`, new): 3 training days per stick, then rest 1 day, then 2, and so on. 10 sticks = 45 days. Same session length every day (default 15 min). New courses start 3 days after the last one. Tabs: **Today** (stick, day, task, minutes, what I learned, Done), **Curriculum** (resource, goal, Day 1–3 tasks, how I'll use it, done when, per stick), and **Progress** (sticks done, a 45-day calendar, streak). Missed days stay missed. Tap one to log a make-up.

**Free vs VIP for every tool** (Trick Talk is not changed). The database enforces these too, so they can't be skipped:
- **Cash & Hours Ledger:** free = 1 ledger and 10 receipts. VIP = unlimited, plus full statements, printing and share links.
- **Focus Room:** free = Sprint mode, 1 session every 24 hours. VIP = every mode, no limit, calm sound, the weekly chart and full history.
- **Formidable Routine:** free = the basic morning and evening checklists, leave time and sleep. VIP = your own steps, rough morning, School Hour, Qigong, reading goal, mood check-in, the Business tab and the Week tab.
- **Weekly Wheel:** free = the Wheel of Life for this week. VIP = your week, the Inner Wheel and Peace score, priorities and goals, last week vs this week, and history.
- **Sticks School:** free = 1 course, plan stick 1, log today. VIP = 3 courses, all 10 sticks, the Progress tab and make-up days.
- **Shadow Journal:** free = 2 of 7 gates (same as before).
- Free members see the last 3 days of routine data. Any locked part shows a gold VIP card with a Join VIP button.

**Privacy:** moods, feelings, notes, wheel scores and school notes can only be read by the member. Not other members, not the Lounge, not profiles, not admins.

## Update 15 (all-in-one), now part of update 16

1. In Supabase, open **SQL Editor**, paste all of `supabase-update-15.sql`, and tap **Run**. This one file includes updates 12, 13 and 14, so you do not need to run those. It is safe to run more than once, and safe if you already ran any of them. If anything fails, nothing changes.
2. Upload `index.html`, `sw.js` and `README.md` to GitHub.

**Formidable Routine** (Tools):
- **Morning:** Wake + Align 5, Exercise 5+, Fuel + Word 15, Prayer 5, Meditate 15, Journal 15, Reset 20, Enterprise Hour 30, Walk the dog 15, Buffer 15, then Leave. Start times count back from the leave time (default 7:30 AM).
- **Make it yours:** tap **Edit my morning**, **Edit my evening**, or **Edit my prep list**. Add your own steps (with minutes, and for the morning, where it goes), or tap × to remove any step. **Put them back** brings our steps back. Times update right away.
- **Exercise ladder:** 5 min in week 1, plus 2 min each week, up to 15. The wake time moves earlier to match.
- **Rough morning:** a switch for the short version. Each person picks their steps in Settings (up to 35 min).
- **Evening:** starts at wake time minus 6.5 hours of sleep minus the length of the evening list (60 min to start), plus a night-before prep list.
- **Business:** this week's Enterprise Hour plan, notes for each week, and today's scoreboard.
- **Free vs VIP:** free members get the checklists, the plan, and today's scoreboard. VIPs also get weekly totals, streaks, and the History tab.

## Update 14 (Nov 2026 redesign) — now part of update 15

What it added:
- **Bottom tabs:** Home · Shelf · Tools · Lounge · Me. Admin pages are on the Me page (admins only).
- **Home:** "Pick up where you left off", "New since your last visit", one "Your next step" card, then the offers (VIP, the Codex at $33, and gifts).
- **Shelf:** a 2-column card grid with filters (All · Growth · Business · Scripture · Classics · Toolkit), a search box, and a Saved button. Tapping a locked item opens a short note with Upgrade and Not now.
- **Tools:** Cash & Hours Ledger, Focus Room (beta), Shadow Journal, and Trick Talk. The ones a person uses most move to the top.
- **Cash & Hours Ledger:** hours worked or cash paid, live math, receipt numbers, a ready-to-text receipt, Mark confirmed, Void and Restore (nothing is ever deleted), and Copy full statement. A rate change only counts for new entries. Free: 1 ledger. VIP: unlimited ledgers, a view-only share link, and printing.
- **Focus Room (beta):** one task, four timer modes (Sprint, Deep Work, Flow, Custom), a shrinking gold ring, Focus Mode (dims the screen, keeps it on, counts each time you leave), park-a-thought, a check-in at the end, today's log, a weekly chart, "Focusing now" with other members, and a link to the live focus table in Trick Talk. VIP: full history and time by tag. Note: a web app cannot block other apps on a phone.
- **Lounge:** "Join a live table" button for Trick Talk. VIP rooms show the gold VIP badge.

## Download the App button

A gold "Download the App" button sits above the bottom menu. It only shows where the phone or browser can install the app (Android, Chrome, Edge, iPhone, iPad, and Safari on Mac). On Android and Chrome it opens the normal install box. On iPhone it shows 3 easy steps (Share → Add to Home Screen → Add). It goes away for good once the app is installed or opened from the home screen.

## Settings to fill in (top of `index.html`)

   - `DONATE_PAYPAL_URL`: paste your PayPal donate link. The "Give with PayPal" button shows up once it is filled in.
   - `CODEX_REGULAR_PRICE`: the price shown after the sale ends (Nov 15, 11:59 PM Central). It is set to `$33`.

## Shelf rows

Personal Growth, Business Development, Scripture, Old Books, Toolkit, The Council. Pick the row in **Admin → Shelf**. An empty row shows a "Coming soon" card.

## Access labels

Only three: **Free** (no account needed), **Free account** (sign up, no payment), **VIP**. VIP cards show a lock.

## Getting paid

- **VIP by PayPal or card:** the "Join VIP — $7/month" button goes to https://mindonesbusiness.systeme.io/vip (`VIP_CHECKOUT_URL`). If the person is not signed in, the app has them make a free account first, then sends them to checkout.
- **VIP by Bitcoin:** the Blockonomics button ($7 = 30 days).
- After each payment, email a VIP code within 24 hours. Make codes in the SQL Editor:

```sql
select * from public.generate_vip_codes(20, 'MEMBERSHIP', 30);   -- 30-day codes
select * from public.generate_vip_codes(50, 'CODEX', 90);        -- Codex codes (3 months of VIP)
```

Each code adds time on top of what the person has left.

- **Codex:** "Buy the Codex" goes to https://codex.mindonesbusiness.com (`CODEX_URL`). The Codex is its own product. It comes with 3 months of VIP. VIP does not include the Codex.
- **Gifts:** Bitcoin ($1 or more), and PayPal once `DONATE_PAYPAL_URL` is set.

## After you change `index.html`

Change `VERSION` in `sw.js` (now `mobvault-v31`) so phones get the update.
