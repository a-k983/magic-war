# Getting Magic War onto iOS with real ads

Where things stood on 2026-10-30, and what to do when you come back to this.

## What is already done

- The revive and x2 boost offers are built and tested.
- All ad calls go through one file, `autoload/ads.gd`.
- Debug builds show a labelled TEST AD. Release builds have `enabled = false`,
  so every offer stays hidden until real ads are connected.
- Offer timing is in `config/balance.tres`, under the Ads group.

## What you need first

| Item | Notes |
|---|---|
| MacBook with Xcode | From the Mac App Store. Open it once to finish setup. |
| Godot 4.7 for macOS | Same version as this project. |
| Godot export templates | In Godot: Editor > Manage Export Templates. |
| Apple Developer Program | Paid yearly membership. Needed for TestFlight and the App Store. |
| AdMob account | Free. Create the app and a rewarded ad unit there. |
| An iPhone | The iOS simulator only supports the Compatibility renderer and this project uses Mobile, so test on a real phone. |

## Step 1: Get the project onto the Mac

**Cloning from GitHub is not enough.** `scenes/assets/` (the Tiny Swords and
Items art packs) is git-ignored because of its licence, so a clone is missing
all the art. The game will not run without it.

1. Clone the repo on the Mac.
2. Copy `scenes/assets/` from the Windows PC into the same place, using a USB
   drive or cloud storage. Do not commit it.
3. Open the project in Godot and let it import. This takes a few minutes.
4. Press Play and confirm the game runs on the Mac.

## Step 2: Export to Xcode

Godot does not build the iPhone app itself. It writes an Xcode project, and
Xcode does the building, signing and uploading.

1. In Godot: Project > Export > Add... > iOS.
2. Fill in the two required fields. The export fails if either is blank.
   - **App Store Team ID**: the 10-character code on your Apple Developer
     account page, not your name.
   - **Bundle Identifier**: a unique reverse-domain name, such as
     `com.yourname.magicwar`. Letters, digits, hyphens and periods only.
3. Click Export Project, and choose an **empty folder** outside the project.
4. Name the file without spaces, such as `MagicWar`. Spaces can corrupt the
   Xcode project.
5. Leave "Export With Debug" on while testing. That keeps the TEST AD working.

If it fails with an SDK path error, run this in Terminal:

```bash
sudo xcode-select -switch /Applications/Xcode.app
```

## Step 3: Run it on your iPhone

1. Open the exported `MagicWar.xcodeproj` in Xcode by double-clicking it.
2. Plug in the iPhone and pick it from the device list at the top of Xcode.
3. Click the project in the left sidebar, open Signing & Capabilities, and pick
   your team.
4. Press the Play button in Xcode.

The first time, the iPhone may ask you to turn on Developer Mode and trust your
account in Settings.

After changing the game, export from Godot again into the same folder and
press Play in Xcode again.

## Step 4: Connect real ads

This is the only code work left, and it can be done together in a session.

1. **Choose a plugin.** The likely candidate is godot-sdk-integrations/godot-admob
   (MIT licence, enabled in the addons list and again in the iOS export preset).
   Its latest asset-library listing found was v6.0, built for Godot 4.5.
   **Godot 4.7 support and rewarded-ad support were not confirmed**, so check
   its README and releases first. If it does not support 4.7, the choices are a
   newer plugin release, rebuilding it, or changing Godot version.
2. **Add your AdMob app ID** to the app as `GADApplicationIdentifier`.
3. **Fill in `autoload/ads.gd`.** Its header comment lists the three changes:
   `is_available()` is true once an ad has loaded, `show_rewarded()` plays it,
   and `finish(true)` runs only when the network confirms the reward.
4. **Use Google's test ad unit while developing:**
   `ca-app-pub-3940256099942544/1712485313`. Clicking real ads on your own
   device, or testing with them, can get your AdMob account suspended.
5. Swap in your own ad unit ID just before release.

## Step 5: Upload to the App Store

1. Create the app in App Store Connect, using the same Bundle Identifier.
2. Export from Godot with "Export With Debug" **off**.
3. In Xcode: set the device to "Any iOS Device", then Product > Archive.
4. In the window that opens, choose Distribute App and upload it.
5. Test through TestFlight first, then submit for review.

## Before submitting, check these

Confirm the current rules on Apple's and Google's own pages, because these were
not fully verified:

- **App Tracking Transparency**: Apple's tracking permission prompt.
- **Consent form** for EU and UK players, through Google's UMP SDK.
- **App privacy details** in App Store Connect, declaring the ad data collected.
- **app-ads.txt** on a website you own, listed on the store page.
- **Age rating and audience**: if the game is aimed at children, ad rules are
  much stricter.
- **Art licences**: confirm the Tiny Swords and Items packs allow commercial
  release in a game with ads.
- **The revive and boost offers stay opt-in**, as rewarded ads must be. They are
  today.
- **Before launch, review `fireball_damage = 20`** in `config/balance.tres`,
  which looked like a test value. See the matching starter weapon values too.

## Sources

- [Godot: Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Google: AdMob iOS rewarded ads](https://developers.google.com/admob/ios/rewarded)
- [Godot asset library: iOS AdMob Plugin](https://godotengine.org/asset-library/asset/edit/20615)
