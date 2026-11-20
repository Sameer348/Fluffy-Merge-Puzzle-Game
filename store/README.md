# Fluffy Merge: store release kit

Everything needed to submit version **1.0.0 (build 1)** to Google Play and
the App Store. Regenerate any image with the scripts in `tool/`.

| Item | Google Play | App Store |
|---|---|---|
| App ID | `com.fluffymerge.fluffy_merge` | `com.fluffymerge.fluffyMerge` |
| App icon | `google_play/icon_512.png` | `app_store/app_icon_1024.png` (no alpha) |
| Feature graphic | `google_play/feature_graphic_1024x500.png` | n/a |
| Phone screenshots | `google_play/phone/` (1080 × 2160) | `app_store/iphone_6_9/` (1320 × 2868) |
| Tablet screenshots | `google_play/tablet/` (2064 × 2752) | `app_store/ipad_13/` (2064 × 2752) |
| Privacy policy | `docs/privacy_policy.md` (host it, see below) | same URL |

Both App IDs are permanent once the app is published.

---

## 1. Before the first upload

1. **Fill in a support email.** Replace `SUPPORT_EMAIL` in
   `docs/privacy_policy.md`. Both stores also ask for one.
2. **Host the privacy policy.** In the GitHub repo go to Settings → Pages,
   then set Source to "Deploy from a branch", branch `main`, folder `/docs`.
   The policy will be at
   `https://sameer348.github.io/Fluffy-Merge-Puzzle-Game/privacy_policy`.
3. **Android upload key.** Run `tool/release/make_upload_key.sh`. It asks for
   a password, creates the keystore and writes `android/key.properties`
   (git-ignored). Back up the keystore and password somewhere safe.
4. **iOS signing.** In Xcode open `ios/Runner.xcworkspace`, go to
   Runner → Signing & Capabilities, choose your Team and keep
   "Automatically manage signing" on. Then add the **In-App Purchase**
   capability.

## 2. Build

```bash
flutter test
```
```bash
flutter build appbundle --release
```
```bash
flutter build ipa --release
```

- The Android bundle is in `build/app/outputs/bundle/release/app-release.aab`.
  Upload it to Play Console → Testing → Internal testing first.
- For iOS, open `build/ios/archive/Runner.xcarchive` in Xcode → Organizer →
  Distribute App, or upload the `.ipa` from `build/ios/ipa/` with Transporter.
- For the next release, bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`).
  Keep `lib/core/constants/app_info.dart` in step.

## 3. In-app products

Create these in Play Console → Monetize → Products, and in App Store
Connect → In-App Purchases. Use **exactly** these IDs:

| Product ID | Type | Suggested price | Gives |
|---|---|---|---|
| `coins_500` | Consumable | $0.99 | 500 coins |
| `coins_1500` | Consumable | $1.99 | 1,500 coins |
| `coins_5000` | Consumable | $4.99 | 5,000 coins |

> Don't create `remove_ads` yet. This release shows no ads, so the shop
> hides "Remove Ads" (selling it would do nothing). Add the product
> (non-consumable) only in the update that adds an ad network.

The shop only shows coin packs once the store returns these products, so
the app works before they exist. It just says "coming soon".

---

## 4. Listing text

**App name** (30 max): `Fluffy Merge`

**Play short description** (80 max):
`Drop, merge and grow the fluffiest puffs in a cozy physics puzzle!`

**App Store subtitle** (30 max): `Cozy physics merge puzzle`

**App Store keywords** (100 max):
`merge,puzzle,cute,drop,physics,casual,relaxing,kawaii,plush,match,combo,offline`

**Full description** (both stores):

```
Drop fluffy puffs into the jar, match two of a kind and watch them merge into something bigger and fluffier!

Fluffy Merge is a cozy physics puzzle with squishy, bouncy creatures. Every puff wobbles, blinks and reacts, so stacking them never gets old.

HOW TO PLAY
• Drag to aim, release to drop.
• Two puffs of the same kind merge into the next one.
• Chain merges for combos and bonus points.
• Don't let the jar overflow past the dotted line!

FEATURES
• 12 adorable puffs to discover, from Tiny Puff to the legendary top level
• Satisfying, real physics: puffs roll, squish and bounce
• Power-ups when you're stuck: Sweep, Pop, Grow and Shake
• Daily challenges and a 7-day reward streak
• Collection book with every puff you've met
• Jar skins and storybook scenes to unlock with coins
• Plays offline, with no account needed
• No ads
• Gentle on the senses: reduced-animation mode, sound and haptics toggles

Your progress stays on your device. We collect no data.
```

**Category:** Games → Puzzle (Play) · Games → Puzzle, Casual (App Store)

---

## 5. Questionnaires

### Google Play: Data safety
- Does your app collect or share any of the required user data types? **No**
- Is all user data encrypted in transit? n/a (no data leaves the device)
- Do you provide a way for users to request data deletion? n/a (on-device only; uninstalling deletes it)

### Google Play: other declarations
- **Ads:** No, the app doesn't contain ads
- **Target audience:** 13+ is the simplest. Choosing under-13 brings in the
  Families policy. The game itself is suitable for all ages.
- **Content rating (IARC):** no violence, no user interaction, no
  gambling, but it has in-app purchases. Expect *Everyone / PEGI 3*.
- **App access:** all functionality is available without special access.

### App Store: App Privacy
- **Data collection:** "No, we do not collect data from this app"
- **Tracking:** No (no ATT prompt needed; the privacy manifest
  `ios/Runner/PrivacyInfo.xcprivacy` declares no tracking)

### App Store: other
- **Age rating:** all answers "None", which gives 4+
- **Export compliance:** handled. `ITSAppUsesNonExemptEncryption = NO`
  in Info.plist, so there's no prompt on upload.
- **Review notes:** "Single-player offline puzzle game. No login required.
  Coin packs are optional consumable purchases."

---

## 6. Release checklist

- [ ] `flutter test` passes
- [ ] Support email filled in; privacy policy URL live
- [ ] Android: `key.properties` present; `flutter build appbundle` signs with
      the upload key (no "signing release with the DEBUG key" warning)
- [ ] Android: install the release build on a real phone; play a full run
- [ ] iOS: Team set, In-App Purchase capability added, archive uploads
- [ ] iOS: TestFlight build tested on a real iPhone
- [ ] In-app products created with the IDs above (and approved on iOS)
- [ ] Buy each coin pack with a Play test account / Sandbox Apple ID
- [ ] Listing text, screenshots, icon, feature graphic uploaded
- [ ] Data safety / App Privacy / content rating completed
- [ ] Roll out: Play internal testing → closed → production;
      App Store: TestFlight → submit for review

## Regenerating assets

```bash
flutter test tool/icons/render_icons_test.dart
```
```bash
python3 tool/icons/make_icons.py
```
```bash
flutter test tool/store_assets/screenshots_test.dart
```
```bash
python3 tool/store_assets/make_store_screens.py
```
The Python scripts need Pillow (`pip3 install pillow`).
