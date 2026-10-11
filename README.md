# MOB Vault — mobile.mindonesbusiness.com

Tarot-style booklet app for MindOnesBusiness. It installs to a phone's home screen, has free and VIP tiers, a members-only forum (the Guild Hall), and a private journal.

## What's in this folder

| File | What it does |
|---|---|
| `index.html` | The whole app. Settings (Supabase keys, theme, VIP price, payment link) are at the top. VIP is set to $22/month. |
| `supabase-setup.sql` | Builds the database: members, VIP keys, library, forum, and Volume I content. |
| `supabase-update-1.sql` | Adds VIP expiration dates and timed keys (30-day membership, 180-day Codex). Run after the setup file. |
| `brand-logo.jpg`, `manifest.json`, `sw.js`, icon PNGs | Make it installable as a phone app and let it open offline. |
| `CNAME` | Tells GitHub Pages to serve the app at mobile.mindonesbusiness.com. |

## Go live in 5 steps

**1. Build the database.** In Supabase, open **SQL Editor → New query**, paste all of `supabase-setup.sql`, and click **Run**. Then do the same with `supabase-update-1.sql`.

**2. Point Supabase at your address.** Go to **Authentication → URL Configuration**. Set **Site URL** to `https://mobile.mindonesbusiness.com` and add the same address under **Redirect URLs**. (Without this, sign-up confirmation emails link to the wrong place.)

**3. Keys are already in.** Your Project URL, anon key and the three Blockonomics button ids are set in the `CONFIG` block near the top of `index.html`. Never paste the `service_role` key anywhere.

**4. Put it on GitHub Pages.** Create a **new repository** (each GitHub Pages site gets one custom domain, so this can't share the main site's repo). Upload every file in this folder, then go to **Settings → Pages**, set the source to the `main` branch, and confirm the custom domain reads `mobile.mindonesbusiness.com`. Tick **Enforce HTTPS** once it's offered.

**5. DNS in Namecheap.** Add a **CNAME record** with host `mobile` and value `YOUR-GITHUB-USERNAME.github.io`.

## Making someone VIP

**Payments come in through three Blockonomics buttons:** $22 membership (Account tab), $100 Codex pre-sale (Shelf), and $1+ donations (Shelf). Each checkout collects the buyer's email.

**When a payment arrives, email the buyer a key.** Generate keys in the Supabase SQL Editor:

```sql
-- Membership: 30 days each
select * from public.generate_vip_codes(20, 'MEMBERSHIP', 30);
-- Codex pre-sale: 6 months each
select * from public.generate_vip_codes(50, 'CODEX-PRESALE', 180);
```

Each key (like `MOB-7F3A-91C2`) works once. The buyer enters it on the Account tab and VIP turns on instantly. A renewal key **adds** 30 days to whatever time is left. When the time runs out, access locks and the Account tab shows a Renew button.

```sql
-- Unused keys
select code, source, days from public.vip_codes where redeemed_by is null order by created_at;
-- Who is VIP and until when
select display_name, is_vip as lifetime, vip_until from public.profiles order by vip_until desc nulls last;
```

Donations don't need a key.

**Next upgrade:** automatic activation, where a Blockonomics payment switches on VIP with no key to send.

**Make yourself VIP / admin.** In **Table Editor → profiles**, find your row and set `is_vip` to `true`. That's a lifetime override that never expires.

## Everyday changes

- **Seasonal reskin:** change `THEME` in `CONFIG` (`gilded` is the brand default; `halloween`, `classic`, `winter` are seasonal), or copy a block in `THEMES` and edit the colors.
- **Edit booklet text:** Supabase **Table Editor → page_bodies**. Changes show up the next time the app opens.
- **Add a new volume:** add a row to `volumes`, then its rows to `pages` and `page_bodies`. Set a page's `tier` to `vip` to seal it.
- **Open the Codex:** change the `codex-7-gates` volume's `status` from `soon` to `live` once its pages are in.
- **Forum categories:** edit the `forum_categories` table.
- **Swap the logo:** replace `brand-logo.jpg` and the icon PNGs.
- **After editing `index.html`:** bump `VERSION` in `sw.js` (for example `mobvault-v4`) so installed phones pick up the update.

## How VIP content stays protected

Page lists and teasers are public. The actual words of VIP pages live in `page_bodies`, and Supabase only hands them to accounts marked VIP. The forum works the same way. Members can't make themselves VIP, because the only path is a valid one-time key or you flipping the switch.
