# App Store Metadata — NeighborhoodSkout

## App Store Connect basics

| Field | Value |
|---|---|
| Bundle ID | `mp.NeighborhoodSkout` |
| SKU | `neighborhoodskout-v1` |
| Primary language | English (U.S.) |
| Category | Utilities (primary) / Lifestyle (secondary) |
| Age rating | 4+ |
| Price | Free |

---

## Localizations

### English (U.S.)

**Name** (30 chars max)
```
NeighborhoodSkout
```

**Subtitle** (30 chars max)
```
Your private neighborhood map
```

**Description** (4000 chars max)
```
NeighborhoodSkout is a private neighborhood directory that lives entirely on your device. Build a visual map of your street, add the people who live in each house, and never worry about your neighbors' information being shared, sold, or seen by anyone but you.

FEATURES

• Visual map — place houses on a street grid that matches your actual neighborhood layout. Choose from four street templates (both sides, left only, right only, cul-de-sac).

• Resident profiles — record first name, last name, birthday, family role, and optional LINE ID for each person. Add a photo for each resident and each house.

• Birthday reminders — get a local notification on (or the day before) each neighbor's birthday. Notification time and schedule are fully customizable in Settings.

• LINE integration — tap a resident's LINE ID to open a chat directly in LINE, with a clipboard fallback if the app isn't installed.

• CSV export & import — export your neighborhood to a CSV that opens in Excel, Numbers, or Google Sheets. Re-import later to merge changes by house ID, so updates from one device can be brought over without overwriting unrelated data.

• Automatic backups — every import and restore creates a timestamped backup. Restore any of the last five backups from the Settings screen.

• Decoration mode — add emoji decorations (trees, flowers, cars, lanterns, and more) to individual houses to personalize your map.

• Fully offline — no account required, no server, no analytics. Your neighbors' names, birthdays, and LINE IDs never leave your device.

• English & Japanese — the app is fully localized in both languages and follows your device language setting automatically.
```

**Keywords** (100 chars max, comma-separated)
```
neighborhood,directory,map,residents,community,privacy,local,contacts,birthday,street
```

**Support URL**
> You need to host a support page. A simple GitHub repository page, Notion page, or even a brief page on your own site works. Apple requires a reachable URL.

**Marketing URL** (optional)
> Leave blank or add a landing page later.

**Privacy Policy URL**
> Required for submission. See the Privacy Policy section below.

**What's New** (first release — leave blank or use the default)
```
First release.
```

---

### Japanese (日本語)

**Name**
```
NeighborhoodSkout
```

**Subtitle**
```
プライベートな近隣マップ
```

**Description**
```
NeighborhoodSkoutは、完全にデバイス上で動作するプライベートな近隣ディレクトリアプリです。実際の街の様子を再現したビジュアルマップを作成し、各家に住む人々の情報を記録できます。近隣の方々の個人情報が外部に共有・販売されることは一切ありません。

主な機能

• ビジュアルマップ — 実際の街の配置に合わせた通りのグリッドに家を配置できます。両側、左側のみ、右側のみ、袋小路の4種類のテンプレートから選択可能。

• 居住者プロフィール — 氏名、誕生日、家族内の役割、LINE IDを記録。各居住者・各家に写真を追加できます。

• 誕生日リマインダー — 近隣の方の誕生日当日または前日にローカル通知でお知らせ。通知時間や設定はカスタマイズ可能。

• LINE連携 — 居住者のLINE IDをタップするだけでLINEのチャットを開けます。LINEが未インストールの場合はクリップボードにコピー。

• CSV書き出し・読み込み — Excel、Numbers、Google Sheetsで開けるCSVとして書き出し。家のIDで変更をスマートに結合して再読み込み可能。

• 自動バックアップ — 読み込みや復元のたびにバックアップを自動作成。設定画面から最大5件のバックアップを復元できます。

• デコレーションモード — 木、花、車、提灯などの絵文字で各家をカスタマイズ。

• 完全オフライン — アカウント不要、サーバーなし、分析なし。近隣の名前・誕生日・LINE IDがデバイス外に出ることはありません。

• 英語・日本語対応 — デバイスの言語設定に合わせて自動で言語が切り替わります。
```

**Keywords**
```
近隣,ディレクトリ,マップ,居住者,コミュニティ,プライバシー,地域,誕生日,通り
```

---

## Privacy policy

Apple requires a hosted privacy policy URL. Here is a minimal template you can host as a plain HTML page or Markdown file on GitHub Pages, Notion, or your own site.

```
Privacy Policy — NeighborhoodSkout
Last updated: [date]

NeighborhoodSkout does not collect, transmit, or share any personal data.

All information you enter — including names, birthdays, LINE IDs, and photos — is stored only on your device in the app's private Application Support directory. It is never sent to any server, third party, or cloud service by this app.

The app does not use analytics, advertising SDKs, crash reporters, or any other third-party services that could access your data.

Birthday notifications are scheduled locally on your device using iOS's notification system. No notification content is sent over the network.

If you have questions, contact: [your email]
```

---

## App icon checklist

The Xcode project already has `myBlocks_1024.jpg` in the universal (light) slot. Before submitting:

- [ ] **Dark icon** — add a dark-mode variant at 1024×1024 in `Assets.xcassets/AppIcon.appiconset/` and set `"filename"` in `Contents.json` for the dark appearance entry.
- [ ] **Tinted icon** — add a tinted (monochrome) variant at 1024×1024 (grayscale or near-monochrome) for the tinted appearance entry.
- [ ] Confirm the icon has **no alpha channel** — App Store Connect rejects icons with transparency (JPEG is safe; ensure any PNG is opaque).
- [ ] Confirm **no rounded corners** in the icon source — iOS applies its own mask.

---

## Screenshots

App Store Connect requires at minimum one screenshot set. Recommended sizes for a universal iPhone app:

| Device class | Canvas size |
|---|---|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 × 2868 px |
| iPhone 6.7" (iPhone 15 Plus) | 1290 × 2796 px |

Supplying the 6.9" set is enough to satisfy all iPhone sizes (App Store Connect will scale down). Suggested shots (5 max displayed, aim for 4–5):

1. **Map overview** — a populated street with colored houses, emoji decorations, and birthday badges visible.
2. **Residents view** — a house with several residents shown, including a photo and the LINE button.
3. **Person form** — the edit screen showing birthday picker and photo section.
4. **Birthday notification** — screenshot of the lock screen notification (can be a mockup).
5. **Settings screen** — notification time and backup list.

Take screenshots in the iOS Simulator:
```
Device → iPhone 16 Pro Max → run app → Device menu → Take Screenshot
```

---

## Archive & upload checklist

Run these steps in Xcode on your Mac (not in Claude Code):

- [ ] Set scheme to **NeighborhoodSkout** → **Any iOS Device (arm64)**
- [ ] Product → **Archive**
- [ ] In Organizer: **Distribute App** → **App Store Connect** → Upload
- [ ] In App Store Connect: add the build to your TestFlight group, test on a real device
- [ ] Fill in all metadata above, upload screenshots, set privacy nutrition label
- [ ] Submit for review

### Privacy nutrition label (App Store Connect)

Under **Data Not Collected**, confirm:
- Contact info: Not collected
- Health & fitness: Not collected
- Financial info: Not collected
- Location: Not collected
- Sensitive info: Not collected
- Identifiers: Not collected
- Usage data: Not collected
- Diagnostics: Not collected

All data the user enters (names, birthdays, LINE IDs, photos) stays on their device and is never transmitted — so the label is "Data Not Collected."
