# Deploy Mano Agency as a web app

Target URL: **https://mano-agency.henderlandcorps.in**

## Detected setup

I checked the domain while preparing this guide:

- `henderlandcorps.in` currently resolves to Hostinger's parked page (`2.57.91.91`) and uses Hostinger DNS.
- `mano-agency.henderlandcorps.in` does not exist yet, so you must create the subdomain.
- A parked domain cannot serve the app by itself. You need either a Hostinger hosting plan or a free static host.
- The easiest path is **Hostinger hosting + hPanel** (Option A below).
- If you do not have a Hostinger hosting plan, you can host the static build for free on Cloudflare Pages, Netlify or Vercel (Option C) and create the DNS record in Hostinger.

## Short answer

This project is already a Flutter app with web support enabled. You do **not** need to rewrite it in another framework. Flutter compiles the same Dart code into a static web app (HTML, JavaScript, WebAssembly and assets), and you upload that static build to the subdomain.

The production files are generated in:

```text
build/web/
```

Everything inside `build/web` is the website. Upload the **contents** of that folder, not the folder itself.

## Important: where the data lives

The app stores stock and sales in the browser using `shared_preferences`, which becomes **localStorage** on the web.

That means:

- Each browser/device has its own separate data.
- Data is tied to the exact origin, so data from `localhost` or the Android app does **not** move to the new subdomain automatically.
- Clearing browser/site data deletes the stock and sales history.
- Private/incognito windows lose data when closed.
- Multiple devices do **not** share the same shop data.

If you need one shared database for several phones/computers, you need a backend such as Supabase or Firebase plus login. That is a separate feature; ask before relying on the web version for multi-device use.

## 1. Build the web app

From the project root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1
```

Or manually:

```powershell
flutter pub get
flutter build web --release --base-href / --no-web-resources-cdn
```

On macOS/Linux:

```bash
bash scripts/build_web.sh
```

The `--base-href /` is correct because the app will live at the root of its own subdomain. If you later deploy it inside a folder such as `henderlandcorps.in/mano-agency/`, rebuild with `--base-href /mano-agency/` instead.

Before uploading, confirm that `build/web` contains:

```text
index.html
main.dart.js
flutter_bootstrap.js
flutter_service_worker.js
manifest.json
version.json
assets/
canvaskit/
icons/
.htaccess          (on Apache/cPanel)
_headers           (on Netlify/Cloudflare Pages)
_redirects         (on Netlify/Cloudflare Pages)
```

## 2. Choose where the subdomain will be hosted

### Option A — Hostinger hPanel (recommended for this domain)

`henderlandcorps.in` currently uses Hostinger DNS and shows Hostinger's parked page, so this is the shortest path if you have (or buy) Hostinger hosting.

1. Log in to [hPanel](https://hpanel.hostinger.com).
2. Open the hosting plan for `henderlandcorps.in`.
3. Go to **Websites → Manage → Subdomains** (the exact menu label can vary slightly).
4. Create:
   - Subdomain: `mano-agency`
   - Domain: `henderlandcorps.in`
   - Custom folder: `public_html/mano-agency` (or leave the default and note it)
5. Save. Hostinger creates the DNS record automatically when the domain uses Hostinger nameservers.
6. In hPanel, open **File Manager** and go to the subdomain folder.
7. Upload a zip of the **contents** of `build/web` and extract it there. Enable hidden files so `.htaccess` is uploaded.
8. In hPanel, open **Security → SSL** and install the free SSL certificate for `mano-agency.henderlandcorps.in`.
9. Open `https://mano-agency.henderlandcorps.in`.

Hostinger uses LiteSpeed, which reads `.htaccess`, so the included Apache rules work.

> The subdomain folder must contain `index.html` directly. If the zip extracts into an extra folder, move its contents up one level.

If you do **not** have a Hostinger hosting plan, you can still host the app for free on Cloudflare Pages, Netlify or Vercel (Option C) and point the subdomain's DNS from Hostinger to that host.

### Option B — cPanel / other shared hosting

Use this if the domain is on a cPanel host (Hostinger also offers cPanel on some plans, but most Hostinger accounts use hPanel above).

1. Log in to cPanel.
2. Open **Domains → Create A New Domain** (older cPanel: **Subdomains**).
3. Enter:
   - Subdomain: `mano-agency`
   - Domain: `henderlandcorps.in`
   - Document root: `mano-agency.henderlandcorps.in` (or `public_html/mano-agency`)
4. Save. If the domain's DNS is managed by the same cPanel server, the DNS record is created automatically.
5. If DNS is managed elsewhere (Cloudflare, registrar), add a record at that DNS provider:
   - Type: `A`
   - Name: `mano-agency`
   - Value: the server IP address from cPanel
   - TTL: automatic/default
6. Enable HTTPS:
   - cPanel → **SSL/TLS Status** → **Run AutoSSL**, or
   - use the **Let's Encrypt** plugin and issue a certificate for `mano-agency.henderlandcorps.in`.
7. Wait until `https://mano-agency.henderlandcorps.in` shows a valid padlock.
8. Open **File Manager**, go to the subdomain document root, and enable **Show Hidden Files**.
9. Zip the **contents** of `build/web`, upload the zip, and extract it in the document root.
10. Make sure `.htaccess` is present. It handles MIME types, caching, compression and the single-page-app fallback.

> Do not upload the `build` folder or the `web` folder. The document root should contain `index.html` directly.

If the site is on a server that uses Nginx instead of Apache, use `deploy/nginx.conf` as a starting point instead of `.htaccess`.

### Option C — Cloudflare Pages, Netlify or Vercel

These hosts can build from a Git repository or accept a prebuilt folder.

**Build settings:**

| Setting | Value |
|---|---|
| Build command | `flutter build web --release --base-href / --no-web-resources-cdn` |
| Output directory | `build/web` |
| Flutter version | stable |

If the host does not provide Flutter in its build image, either:

- upload the prebuilt `build/web` folder manually (Netlify Drop, Cloudflare Pages direct upload), or
- add a build step that installs Flutter, for example:

```bash
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$PWD/flutter/bin"
flutter pub get
flutter build web --release --base-href / --no-web-resources-cdn
```

**Custom domain:**

1. In the hosting dashboard, add `mano-agency.henderlandcorps.in` as a custom domain.
2. At your DNS provider, add the record the host shows you:
   - Cloudflare Pages: `CNAME` → `<project>.pages.dev`
   - Netlify: `CNAME` → `<site>.netlify.app`
   - Vercel: `CNAME` → `cname.vercel-dns.com`
3. If the domain is already on Cloudflare, you can add the CNAME in Cloudflare DNS and let Cloudflare manage the proxy/SSL.
4. Wait for the host to issue the SSL certificate.

The included `web/_headers` and `web/_redirects` files are copied into `build/web` and are picked up automatically by Netlify and Cloudflare Pages.

### Option D — your own VPS with Nginx

1. Copy the contents of `build/web` to `/var/www/mano-agency/`.
2. Copy `deploy/nginx.conf` to `/etc/nginx/sites-available/mano-agency.henderlandcorps.in`.
3. Enable it:

```bash
sudo ln -s /etc/nginx/sites-available/mano-agency.henderlandcorps.in \
  /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

4. Issue the certificate:

```bash
sudo certbot --nginx -d mano-agency.henderlandcorps.in
```

5. Point the subdomain's DNS `A` record at the server IP.

## 3. DNS checklist

Whatever host you choose, the subdomain needs one of these at the DNS provider for `henderlandcorps.in`:

- `A` record: `mano-agency` → your server IP, or
- `CNAME` record: `mano-agency` → the hostname given by your hosting provider.

Do not create both. This domain currently uses Hostinger DNS, so the normal path is:

- **Hostinger hosting:** create the subdomain in hPanel and Hostinger creates the record automatically.
- **External host (Cloudflare Pages/Netlify/Vercel/VPS):** in Hostinger, open **Domains → DNS / DNS Zone** and add the `CNAME` or `A` record shown by that host.

If the main domain is on Cloudflare, add the record in Cloudflare DNS. If it is on cPanel with local DNS, create the subdomain in cPanel first and let it create the record.

You can verify propagation with:

```bash
nslookup mano-agency.henderlandcorps.in
```

## 4. After deployment

Open **https://mano-agency.henderlandcorps.in** and check:

- The page loads with a padlock and no certificate warning.
- The Mano Agency logo and loading screen appear, then the home screen.
- You can add a product and create a bill.
- PDF print/download opens the browser print dialog.
- Excel import works with an `.xlsx` file.
- OCR scanning works. The first scan downloads Tesseract.js and its language data, so it needs an internet connection and may take a few seconds.
- The browser asks for camera permission when you choose **Open camera**. Camera access requires HTTPS.
- On a phone, the browser menu offers **Add to Home Screen** / **Install app**.

## 5. Updating the site later

1. Bump the version in `pubspec.yaml` (for example `1.0.0+2`).
2. Rebuild:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1
   ```

3. Upload the new contents of `build/web` and overwrite the old files.
4. If the old version still appears, do a hard refresh (`Ctrl+F5`) or clear the site data once. Flutter's service worker caches the app for offline use.

## 6. Troubleshooting

**Blank page**

- Confirm `index.html` is directly in the document root.
- Confirm all files were uploaded, especially `main.dart.js`, `flutter_bootstrap.js`, `canvaskit/` and `assets/`.
- Open the browser developer console and check for 404s.
- Confirm the build used `--base-href /`.

**404 when refreshing a page**

- Apache: make sure `.htaccess` was uploaded (enable hidden files).
- Netlify/Cloudflare Pages: make sure `_redirects` was uploaded.
- Nginx: use the `try_files $uri $uri/ /index.html;` rule from `deploy/nginx.conf`.

**`WebAssembly` MIME type or `wasm` errors**

- Apache: `.htaccess` adds `application/wasm`.
- Nginx: use the `.wasm` location from `deploy/nginx.conf`.
- Do not rename or remove the `canvaskit` folder.

**OCR does not work**

- The first scan needs internet access because Tesseract.js is downloaded from a CDN.
- If you add a Content-Security-Policy later, allow the Tesseract CDN and blob workers. A strict CSP can block OCR.
- If the browser blocks the camera, check the site permissions and confirm HTTPS is active.

**The camera opens a file picker instead**

On desktop browsers, `ImageSource.camera` may fall back to a file picker. Use a phone, or use **Upload image** instead.

**Old version keeps loading**

- Hard refresh with `Ctrl+F5`.
- Or clear site data for `mano-agency.henderlandcorps.in`.
- As a last resort, build with `--pwa-strategy=none` to disable the service worker cache.

**Data disappeared**

- The app stores data in that browser's localStorage. Clearing site data, using private mode, or switching browsers will show empty data.
- There is no automatic cloud backup or cross-device sync in this version.

## Files added for deployment

| File | Purpose |
|---|---|
| `web/index.html` | Web shell with mobile viewport, loading screen, PWA/social meta tags |
| `web/manifest.json` | Installable PWA metadata and app icons |
| `web/.htaccess` | Apache/cPanel routing, MIME, caching and security headers |
| `web/_headers` | Netlify/Cloudflare Pages headers |
| `web/_redirects` | Netlify/Cloudflare Pages SPA fallback |
| `deploy/nginx.conf` | Nginx server block for a VPS |
| `scripts/build_web.ps1` | Windows release build script |
| `scripts/build_web.sh` | macOS/Linux release build script |

## Recommended next step

If this web app will be used by more than one person or device, plan a backend before entering real shop data. Supabase or Firebase can provide shared stock/bills, authentication and backups while keeping the Flutter UI. The current app is intentionally local-first.
