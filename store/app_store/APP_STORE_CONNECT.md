# Fluffy Merge: App Store Connect, field by field

Copy each value into App Store Connect (appstoreconnect.apple.com → Apps →
Fluffy Merge). Character limits are Apple's; every value here fits.

Bundle ID: `com.fluffymerge.fluffyMerge` · Version: `1.0.0` · Build: `1`

---

## 1. App Information

| Field | Value |
|---|---|
| **Name** (30) | `Fluffy Merge` |
| **Subtitle** (30) | `Cozy physics merge puzzle` |
| **Primary category** | Games |
| **Game subcategories** | Puzzle, Casual |
| **Secondary category** | Entertainment |
| **Content rights** | "No, it does not contain, show, or access third-party content." (All art and sound are original. The fonts are bundled under the SIL Open Font License, which permits this.) |
| **Age rating** | 4+ (answers in section 5) |

## 2. Pricing and Availability
- **Price:** Free
- **Availability:** all countries and regions
- **iPad:** available (the app is built for iPhone and iPad)
- **Mac (Apple silicon) / Vision Pro:** turn off "Make this app available" unless you've tested there

## 3. Version 1.0.0: product page

**Promotional text** (170; can be changed any time without review):
```
Drop fluffy puffs, match two alike and watch them merge into something bigger and fluffier. No ads, no account, plays offline!
```

**Description** (4000):
```
Drop fluffy puffs into the jar, match two of a kind and watch them merge into something bigger and fluffier!

Fluffy Merge is a cozy physics puzzle with squishy, bouncy plush creatures. Every puff wobbles, blinks and reacts, so stacking them never gets old.

HOW TO PLAY
• Drag to aim, release to drop.
• Two puffs of the same kind merge into the next one.
• Chain merges for combos and bonus points.
• Don't let the jar overflow past the dotted line!

FEATURES
• 12 adorable puffs to discover, from Tiny Puff to Rainbow Puff
• Satisfying real physics: puffs roll, squish and bounce
• Power-ups for tight spots: Sweep, Pop, Grow and Shake
• Daily challenges and a 7-day reward streak
• A collection book with every puff you've met
• Jar skins and storybook scenes to unlock with coins
• Original music and sound effects, plus gentle haptics
• Plays offline, with no account needed
• No ads
• Comfort options: reduced animations, and separate sound, music and haptics switches
• Made for iPhone and iPad

Your progress stays on your device. We collect no data.

Optional coin packs are available as in-app purchases. Everything in the game can also be earned by playing.
```

**Keywords** (100, comma-separated, no spaces):
```
merge,puzzle,cute,drop,physics,casual,relaxing,kawaii,plush,match,combo,offline,stack,family
```

| Field | Value |
|---|---|
| **Support URL** | `https://sameer348.github.io/Fluffy-Merge-Puzzle-Game/support` |
| **Marketing URL** (optional) | `https://github.com/Sameer348/Fluffy-Merge-Puzzle-Game` |
| **Privacy Policy URL** | `https://sameer348.github.io/Fluffy-Merge-Puzzle-Game/privacy_policy` |
| **Copyright** | `2026 Fluffy Merge` (or your legal name / company) |
| **Version** | `1.0.0` |
| **What's New** | not shown for the first version |

**Screenshots** (upload in this order; drag to reorder):

| Display | Folder | Size |
|---|---|---|
| iPhone 6.9" | `store/app_store/iphone_6_9_captioned/` | 1320 × 2868 |
| iPhone 6.3" (if asked) | `store/app_store/iphone_6_3_captioned/` | 1206 × 2622 |
| iPhone 6.1" (alternative) | `store/app_store/iphone_6_1_captioned/` | 1179 × 2556 |
| iPad 13" | `store/app_store/ipad_13_captioned/` | 2064 × 2752 |

Apple scales the 6.9" set down for smaller iPhones and the 13" set for
smaller iPads, so these two sets are all you need. Plain versions without
captions are in `iphone_6_9/` and `ipad_13/` if you prefer those.

**App icon:** comes from the build itself (`app_icon_1024.png` is the same image).

## 4. App Privacy

App Store Connect → App Privacy → Get Started:

1. "Do you or your third-party partners collect data from this app?"
   **No, we do not collect data from this app.**
2. Publish. The product page will show **"Data Not Collected"**.

Why this is accurate:
- Progress is stored only on the device (UserDefaults), and never sent anywhere.
- There's no analytics SDK, no ad SDK, no account, and no network calls of the app's own.
- Purchases are processed by Apple (StoreKit). Apple's own processing doesn't count as the developer collecting data.
- The app's privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy`) declares no tracking and no collected data, which matches these answers.

**Tracking:** none, so no App Tracking Transparency prompt is needed.

## 5. Age Rating (content rating)

App Information → Age Rating → Edit. Answer:

**In-app controls and capabilities**

| Question | Answer |
|---|---|
| Parental Controls | No |
| Age Assurance | No |
| Unrestricted Web Access | No |
| User-Generated Content | No |
| Messaging and Chat | No |
| Advertising | No |

**Mature themes**

| Question | Answer |
|---|---|
| Profanity or Crude Humor | None |
| Horror/Fear Themes | None |
| Alcohol, Tobacco, or Drug Use or References | None |

**Medical or wellness**

| Question | Answer |
|---|---|
| Medical or Treatment Information | None |
| Health or Wellness Topics | No |

**Sexuality or nudity**

| Question | Answer |
|---|---|
| Mature or Suggestive Themes | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |

**Violence**

| Question | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Guns or Other Weapons | None |

**Chance-based activities**

| Question | Answer |
|---|---|
| Simulated Gambling | None |
| Contests | None |
| Gambling (real money) | No |
| Loot Boxes | No |

**Result: 4+.** In-app purchases are listed on the product page separately
and don't change the rating.

> "Pop" and "Sweep" remove puffs with a soft poof of sparkles, with no
> harm shown. That's not violence by Apple's definition, so "Cartoon or
> Fantasy Violence" stays **None**.

**Kids Category:** don't opt in. That category forbids external links and
needs extra parental gates, and the game is already rated 4+ for everyone.

## 6. In-App Purchases

App Store Connect → Monetization → In-App Purchases → "+" → **Consumable**.
Create all three. Each needs a 640 × 920 (or larger) **review screenshot**;
use `iphone_6_9/06_shop.png`.

| Reference name | Product ID | Display name (30) | Description (45) | Price |
|---|---|---|---|---|
| Coins 500 | `coins_500` | `500 Coins` | `A small pouch of coins for the shop` | Tier: $0.99 |
| Coins 1500 | `coins_1500` | `1,500 Coins` | `A bag of coins for power-ups and skins` | Tier: $1.99 |
| Coins 5000 | `coins_5000` | `5,000 Coins` | `A big chest of coins for everything` | Tier: $4.99 |

Then attach all three to version 1.0.0 (version page → In-App Purchases →
"+"). A first IAP has to be reviewed together with an app version.

> Don't create `remove_ads`: this version has no ads, and the game hides
> that offer.

## 7. App Review Information

| Field | Value |
|---|---|
| Sign-in required | **No** |
| Contact | your name, phone and email (only Apple sees these) |
| **Notes** | see below |

```
Fluffy Merge is a single-player, offline puzzle game. No account or login is needed.

How to test: tap Play, drag to aim and release to drop a puff. Two matching puffs merge.

In-app purchases: three consumable coin packs (Shop → Coins tab). Coins can also be earned by playing. There are no ads in this version.

The app collects no data. Progress is stored on the device only.
```

## 8. Export compliance

Already answered in the build: `ITSAppUsesNonExemptEncryption = NO` in
Info.plist, so App Store Connect won't ask on upload.

---

## Before you submit
- [ ] Turn on GitHub Pages for the repo (Settings → Pages → branch `main`, folder `/docs`) so the privacy and support URLs work.
- [x] Support email set in `docs/privacy_policy.md` and `docs/support.md`.
- [ ] Create the app record: My Apps → "+" → New App → iOS, name "Fluffy Merge", bundle ID `com.fluffymerge.fluffyMerge`, SKU `fluffymerge001`.
- [ ] Upload a build (Xcode → Product → Archive → Distribute App → App Store Connect), then pick it on the version page.
- [ ] Fill sections 1–7 above, attach the IAPs, then **Add for Review**.
