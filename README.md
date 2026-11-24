# MOB Vault — mobile.mindonesbusiness.com

The member app for MindOnesBusiness: short guides on the Shelf, a private Shadow Journal, the VIP Lounge (with a link to Trick Talk), and member profiles. Free to start. VIP is $7 a month.

## Update 15 (all-in-one) — how to put it live

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

Change `VERSION` in `sw.js` (now `mobvault-v30`) so phones get the update.
