# Mano Agency

A shop inventory and billing app built with Flutter for **Android** and **web**.

## Step 1 — Product stock

- **Home** — three clear actions: *View available stock*, *Add products to stock*, and *Sell products / create a bill*.
- **Add products** — add a product manually with the **+** card, scan a photo of a list, or import an `.xlsx` sheet.
- **Manual entry** — Particulars and Rate are required. Quantity defaults to `1`. The total is calculated automatically. A unique product ID (`PRD-0001`) and serial number are generated for every new product.
- **Duplicate handling** — if the particulars already exist in stock (case and spacing are ignored), no new ID is created. The new quantity and total are added to the existing product; the rate becomes the weighted average.
- **Excel import** — upload a sheet, review the parsed rows, then import. Rows that match existing stock are marked in the preview and merged into the same product.
- **Available stock** — a responsive stock ledger with search. Every product can be managed to update its particulars, rate or quantity.
- **Delete product** — the manage screen has a small red delete icon in the top-right corner. It opens a permanent-delete warning before removing that product from stock and the current bill; past sales and bills are kept.
- **Clear all stock** — the stock page has a small red clear-stock icon in the top-right corner. It opens a red warning and asks for an extra acknowledgement before permanently deleting every product and the current bill. Stock data cannot be recovered; sales history is kept.
- **Short messages** — bottom notifications such as *added to stock* disappear automatically after 2 seconds.

## Step 2 — Selling and bills

- **Create a bill** — see the available stock and tap **+** beside a product once per unit. Each tap adds another unit to the bill; the bill panel shows the running total.
- **Bill quantities** — use **− / +** on a bill line to adjust it. A line can never exceed the quantity available in stock.
- **Scan bill items** — open the camera or upload a photo of a bill/paper list, then match each scanned row to a stock product in the review screen. Quantities bigger than the remaining stock are blocked until corrected.
- **Import bill items** — upload an `.xlsx` item list and review it before adding to the bill. Rows are matched to stock by Product ID, Serial no or Particulars. Out-of-stock and unknown rows are skipped with a reason.
- **Print / download** — print the bill or download it as a PDF using the browser's save dialog on web, or the share sheet on Android.
- **Sell** — after confirmation, the exact bill quantities are deducted from stock, the weighted stock value is kept consistent, and a permanent bill (for example `BILL-0001`) is recorded.
- **Customer name first** — the bill’s customer field can be typed, or selected with the arrow button from any previous customer. The selected name is saved with the bill.
- **Sales history** — bills are grouped under each customer, with the customer name shown first. The list shows the latest bill for each customer; **View all bills from this customer** opens every bill for that customer. Search by customer name to find them quickly. Home and the history screen show totals for **today**, **this week**, **this month** and all time.
- **Clear sales history** — a small red delete icon appears in the sales history top-right corner. It opens a red warning and requires an acknowledgement before permanently deleting every saved bill. Stock and the current bill are not changed; bill numbers are never reused.
- **Discard bill** — each bill card has a red **Discard bill** button for rejected or wrongly entered bills. It asks for confirmation, removes that bill from the history and reports, and returns its quantities to stock. If the product was deleted in the meantime, it is recreated from the bill details. Bill numbers are never reused.

### Excel format

Both stock import and bill item import use the first sheet with these columns:

| Serial no | Rate | Particulars | Quantity | Total |
|-----------|------|-------------|----------|-------|
| 1         | 120  | Sugar       | 2        | 240   |
| 2         | 250  | Tea         |          |       |

- **Required:** Rate, Particulars
- **Optional:** Serial no, Product ID, Quantity (defaults to `1`), Total
- For bill import, Product ID and Serial no are used to find the stock item when present; otherwise Particulars are matched.
- Common header aliases such as `S.No`, `Price`, `Item`, `Qty`, `Amount`, `SKU` and `Product ID` are accepted.

## Scan a list (OCR)

Both **Add products** and **Create a bill** have a **Scan list** button. Choose **Open camera** or **Upload image**, photograph a bill or paper list in the familiar `S.no / Rate / Particulars / Quantity / Total` format, and the app reads the rows into a separate review screen.

- Every scanned row stays separate and editable. Particulars, rate, quantity and total can be corrected, rows can be removed, and missing rows can be added.
- Nothing is saved until **Add to stock** or **Add to bill** is pressed. Cancelling leaves stock and the bill unchanged.
- Stock scans follow the existing duplicate rule: matching particulars merge into the same product ID.
- Bill scans must be matched to a stock product, and cannot exceed the quantity still available after the current bill.
- Android uses on-device Google ML Kit text recognition. Web uses Tesseract.js, which is downloaded on first use, so the first web scan needs an internet connection.

## Run the app

```bash
flutter pub get
flutter run -d chrome   # web
flutter run -d android  # Android device or emulator
```

## Deploy the web app

This project is already a Flutter web app. The production build is a set of
static files in `build/web`, ready to upload to any static host or subdomain.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1
```

Or:

```bash
flutter build web --release --base-href / --no-web-resources-cdn
```

For the full guide — including the `mano-agency.henderlandcorps.in` subdomain,
cPanel, Cloudflare Pages, Netlify, Vercel, Nginx, DNS, HTTPS and troubleshooting
— see **[DEPLOYMENT.md](DEPLOYMENT.md)**.

> Web data is stored in the browser's localStorage. It is not synced between
> devices, and clearing site data deletes it. See the deployment guide for
> details.

## Checks

```bash
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```
