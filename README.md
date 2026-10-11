# MOB Vault — mobile.mindonesbusiness.com

Tarot-style booklet app for MindOnesBusiness. It installs to a phone's home screen, has free and VIP tiers, a members-only forum (the Guild Hall), and a private journal.

## What's in this folder

| File | What it does |
|---|---|
| `index.html` | The whole app. Settings (Supabase keys, theme, VIP price, payment link) are at the top. |
| `supabase-setup.sql` | Builds the database: members, VIP keys, library, forum, and Volume I content. |
| `manifest.json`, `sw.js`, `icon*.png/svg` | Make it installable as a phone app and let it open offline. |
| `CNAME` | Tells GitHub Pages to serve the app at mobile.mindonesbusiness.com. |

## Go live in 5 steps

**1. Build the database.** In Supabase, open **SQL Editor → New query**, paste all of `supabase-setup.sql`, and click **Run**.

**2. Point Supabase at your address.** Go to **Authentication → URL Configuration**. Set **Site URL** to `https://mobile.mindonesbusiness.com` and add the same address under **Redirect URLs**. (Without this, sign-up confirmation emails link to the wrong place.)

**3. Add your keys.** In **Project Settings → API**, copy the **Project URL** and the **anon public** key. Paste them into the `CONFIG` block near the top of `index.html`. The anon key is designed to be public, so this is safe. Never paste the `service_role` key anywhere.

**4. Put it on GitHub Pages.** Create a **new repository** (each GitHub Pages site gets one custom domain, so this can't share the main site's repo). Upload every file in this folder, then go to **Settings → Pages**, set the source to the `main` branch, and confirm the custom domain reads `mobile.mindonesbusiness.com`. Tick **Enforce HTTPS** once it's offered.

**5. DNS in Namecheap.** Add a **CNAME record** with host `mobile` and value `YOUR-GITHUB-USERNAME.github.io`.

## Making someone VIP

**Codex pre-sale buyers / manual sales.** Generate keys in the Supabase SQL Editor:

```sql
select * from public.generate_vip_codes(50, 'CODEX-PRESALE');
```

Each key (like `MOB-7F3A-91C2`) works once. Buyers enter it on the Account screen and VIP turns on instantly. To see which keys have been used:

```sql
select code, source, redeemed_at from public.vip_codes order by created_at desc;
```

**Blockonomics (for now).** Put your Blockonomics payment link in `VIP_PAY_URL`. When a payment comes in, send the buyer a key from the list above. Automatic VIP activation from Blockonomics payments is the next upgrade (a small Supabase function that listens for Blockonomics' payment callback).

**Make yourself VIP / admin.** In **Table Editor → profiles**, find your row and set `is_vip` to `true`.

## Everyday changes

- **Seasonal reskin:** change `THEME` in `CONFIG` (`halloween`, `classic`, `winter`), or copy a block in `THEMES` and edit the colors.
- **Edit booklet text:** Supabase **Table Editor → page_bodies**. Changes show up the next time the app opens.
- **Add a new volume:** add a row to `volumes`, then its rows to `pages` and `page_bodies`. Set a page's `tier` to `vip` to seal it.
- **Open the Codex:** change the `codex-7-gates` volume's `status` from `soon` to `live` once its pages are in.
- **Forum categories:** edit the `forum_categories` table.
- **After editing `index.html`:** bump `VERSION` in `sw.js` (for example `mobvault-v2`) so installed phones pick up the update.

## How VIP content stays protected

Page lists and teasers are public. The actual words of VIP pages live in `page_bodies`, and Supabase only hands them to accounts marked VIP. The forum works the same way. Members can't make themselves VIP, because the only path is a valid one-time key or you flipping the switch.
