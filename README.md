# MOB Vault — mobile.mindonesbusiness.com

The MOB Vault is the member app for MindOnesBusiness.

- **The Shelf:** guides, audio, and video in three swipeable rows: Personal Growth, Business Development, and Miscellaneous.
- **Shadow Journal:** seven gates for seven difficult emotions (Name it · Hear it · Heed it), plus Destiny Lock reflections. Entries stay private on the device.
- **VIP Lounge:** open, unfiltered conversation. Free members get The Commons and Introductions. VIPs get every room.
- **Profiles:** username (also used to sign in), photo, and a short mission statement. VIPs get more room and extra touches.

Guests can preview. A free account opens more. **VIPs** ($7 a month) get everything. Pay with PayPal or crypto.

Look: a dark "desk" of deep green, with ivory used like paper for reading and writing (journal, conversations, profiles, legal pages), and gold-foil accents.

Brand: Heritage Green `#152C28`, Warm Ivory `#F3EFE5`, Antique Gold `#B79B62`, Charcoal `#202423`. Fonts: Marcellus (headings), Cinzel (small capitals), Inter (body text), all from Google Fonts.

## What is in this folder

| File | What it does |
|---|---|
| `index.html` | The whole app. Settings are at the top in `CONFIG`. |
| `logo-emblem.png`, `wordmark.jpg` | The MOB emblem (header and covers) and the MindOnesBusiness wordmark (top of the Shelf). |
| `favicon.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `icon-maskable-512.png` | Browser and home-screen icons. |
| `manifest.json`, `sw.js` | Let people install the app on their phone. |
| `destiny-lock-free-peek.pdf` | The free preview of Destiny Lock. |
| `supabase-setup.sql`, `supabase-update-1.sql` to `supabase-update-11.sql` | Build and update the database. Run them in order. |
| `CNAME` | Points the app to mobile.mindonesbusiness.com. |

The members and full editions of Destiny Lock are **not** in this folder. They are private. Upload them inside the app (Admin → Shelf → Files).

## Update 11 (this release)

1. Upload every file in this folder to GitHub (the new dark theme and the new free preview of Destiny Lock).
2. In Supabase, run `supabase-update-11.sql`. It gives Destiny Lock its cover description.
3. In the app: **Admin → Shelf → Destiny Lock → Files**. Upload the new `destiny-lock-members.pdf` next to **Members edition** and `destiny-lock-vip.pdf` next to **Full edition**. The old files are replaced automatically.

Every Destiny Lock PDF carries the Parallel Construction LLC copyright on every page, a rights notice on the last page, and copyright details in the file's properties.

The **Short description** you type when adding an item is shown on its Shelf cover. Keep it to one sentence.

## Update 10

1. Upload every file in this folder to GitHub. You can delete the old `brand-logo.jpg` from GitHub.
2. In Supabase, open **SQL Editor**, paste `supabase-update-10.sql`, and tap **Run**.
3. Open the app. Go to **Account** and choose your username, photo, and mission statement.
4. In **Admin → Shelf**, use the **Row** menu next to each item to place it in Personal Growth, Business Development, or Miscellaneous. Use **Cover** to add a cover image (tall, 2:3 shape works best). Items without a cover get a branded green-and-gold cover automatically.

Update 10 adds: shelf rows and covers, The Commons room, Introductions opened to free members, usernames and username sign-in, profile photos (the `avatars` storage bucket), mission statements, and VIP profile extras.

## Who sees what

| | Guest | Free member | VIP ($7 a month) |
|---|---|---|---|
| Destiny Lock | Free preview | Members edition | Full edition |
| Other Shelf items | Free items | Free and Members items | All |
| VIP Lounge | Locked | The Commons and Introductions (read and post); VIP room titles shown locked | Every room |
| Journal | Locked | First 2 gates and 1 reflection | Everything |
| Profile | — | Photo, username, 100-character mission statement | 280 characters, gold photo ring, accent color, a link |

## Open conversation

The Lounge does not filter or edit posts. The Terms say posts are only removed if they break the law, threaten or harass someone, are spam, or share someone's private information. To remove a post, delete it in Supabase (**Table Editor → forum_threads** or **forum_posts**).

## Getting paid

**PayPal (VIP, $7 a month).** A person creates a free account, then taps **Subscribe**. It renews monthly.
- Right after they pay, the app makes them a VIP.
- Go to **Admin → Members**, pick **PayPal to verify**, and look up each plan number in PayPal.
  - Real and paid? Tap **Verified**.
  - Not real, or they stopped paying? Tap **End access**, and cancel the plan in PayPal.

**Crypto (Blockonomics).** Three buttons: VIP for 30 days ($7), Codex pre-order ($33), and support ($1 or more). When someone pays, email them a Vault key. Make keys in the SQL Editor:

```sql
-- 30-day keys
select * from public.generate_vip_codes(20, 'MEMBERSHIP', 30);
-- Codex keys (90 days)
select * from public.generate_vip_codes(50, 'CODEX-PRESALE', 90);
```

Each key works once. The person enters it on the Account page.

## Everyday jobs

- **Add something to the Shelf:** Admin → Shelf. Fill in the form, pick the Row, and tap **Publish to Shelf**.
- **Give one guide a free preview, members edition, and full edition:** tap **Files** next to a PDF.
- **Move an item to another row:** change the **Row** menu next to it.
- **Hide or delete something:** **Hide** keeps it; **Delete** removes it for good.
- **Get emails for your list:** Admin → Members → **Not on my list yet** → **Copy emails** or **Download list** → **Mark as on my list**.
- **Make someone an admin:** Admin → Members → **Make admin**.
- **Change mission statement lengths:** `BIO_LIMIT` in `CONFIG`, and the matching numbers (100 and 280) in `update_my_profile` in the SQL.
- **Change prices shown in the app:** `VIP_PRICE_LABEL` and `CODEX_PRICE_LABEL` in `CONFIG`. Change the real price in PayPal or Blockonomics too.
- **Copyright line:** `COPYRIGHT` in `CONFIG`.
- **After you change `index.html`:** change the number in `VERSION` in `sw.js` (for example `mobvault-v21`) so phones get the update.

## How locked things stay locked

The database only sends locked words and files to people allowed to see them. Members cannot make themselves VIPs. Signing in with a username checks the password on the server first, and nobody can look up another person's email.
