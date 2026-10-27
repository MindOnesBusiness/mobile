# MOB Vault — mobile.mindonesbusiness.com

An app with easy books, a private journal, and a members' talk room (the VIP Lounge). It has a Halloween classroom look on a plain off-white page. All the words are written at a 5th grade reading level or lower.

## What is in this folder

| File | What it does |
|---|---|
| `index.html` | The whole app. Settings are at the top in `CONFIG`. |
| `destiny-lock-free-peek.pdf` | The free peek of Destiny Lock. It lives here so anyone can read it. |
| `supabase-setup.sql` and `supabase-update-1.sql` to `supabase-update-9.sql` | Build and update the database. Run them in order. |
| `brand-logo.jpg`, `manifest.json`, `sw.js`, icon PNGs | Let people put the app on their phone. |
| `CNAME` | Points the app to mobile.mindonesbusiness.com. |

The members copy and the VIP copy of Destiny Lock are **not** in this folder. They are private. You upload them in the app (see below).

## Updates 8 and 9

1. Upload every file in this folder to GitHub.
2. In Supabase, open **SQL Editor**. Paste `supabase-update-8.sql`. Tap **Run**. Then do the same with `supabase-update-9.sql`.
3. In the app, sign in as admin. Go to **Add** → **Shelf** → **Destiny Lock** → **Files**.
   - Next to **More for members**, pick `destiny-lock-members.pdf`. Tap **Upload**.
   - Next to **Full for VIPs**, pick `destiny-lock-vip.pdf`. Tap **Upload**.

## Who sees what

| | Guest (no account) | Member (free account) | VIP ($7 a month) |
|---|---|---|---|
| Destiny Lock | Free peek | Members copy (3 ways) | Full book (7 ways and more) |
| Other Shelf items | Free ones | Free and Members ones | All |
| VIP Lounge | Locked | Open rooms, plus locked titles | Every room |
| Journal | Locked | First 2 gates and 1 question | All 7 gates and all questions |

## Getting paid

**PayPal (VIP, $7 a month).** A person must make a free account first. Then they tap the PayPal **Subscribe** button. It renews each month.
- Right after they pay, the app makes them a VIP.
- Go to **Add** → **Members**. Pick **PayPal to check**. Look up each plan number in PayPal.
  - Real and paid? Tap **Checked**.
  - Not real, or they stopped paying? Tap **End access**. Also cancel the plan in PayPal.
- When PayPal tells you someone stopped their plan, find them in Members and tap **End access**.

**Crypto (Blockonomics).** Three buttons: VIP for 30 days ($7), Codex pre-order ($33), and gifts ($1 or more). When someone pays, email them a Vault key. Make keys in the SQL Editor:

```sql
-- 30-day keys
select * from public.generate_vip_codes(20, 'MEMBERSHIP', 30);
-- Codex keys (90 days)
select * from public.generate_vip_codes(50, 'CODEX-PRESALE', 90);
```

Each key works one time. The person types it on the Account page.

## Everyday jobs

- **Add something to the Shelf:** Add tab → Shelf. Fill in the form. Tap **Put It on the Shelf**.
- **Give one book a free peek, a members copy, and a full copy:** tap **Files** next to a PDF book.
- **Hide or delete something:** use **Hide** or **Delete** next to it. Hide keeps it. Delete removes it for good.
- **Get emails for your list:** Add tab → Members. Pick **Not on my list yet**. Tap **Copy emails** or **Download list**. Then tap **Mark as on my list**.
- **Make someone an admin:** Add tab → Members → **Make admin** next to their name.
- **After Halloween:** in `index.html`, change `THEME: 'halloween'` to `THEME: 'classroom'`.
- **Change prices shown in the app:** `VIP_PRICE_LABEL` and `CODEX_PRICE_LABEL` in `CONFIG`. Change the real price in PayPal or Blockonomics too.
- **Copyright line:** `COPYRIGHT` in `CONFIG`.
- **After you change `index.html`:** change the number in `VERSION` in `sw.js` (for example `mobvault-v18`). Then phones get the update.

## How locked things stay locked

The database only gives locked words and files to people who are allowed to see them. Members can't make themselves VIPs.
