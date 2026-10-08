# Private Maps

A personal SwiftUI map app for iOS 17+ and macOS 14+. Apple MapKit supplies the full-screen map and GPS dot; your existing `~/code/scripts/src/google-maps.ts` supplies Google Places search, ratings, details, and photos. No new Swift or Bun dependencies.

The bottom search sheet supports free-text search and nearby categories. Search uses the visible map area, including after panning. Results appear as rating pins; names spread out as you zoom to keep the map readable. Tap a pin or result to open a draggable place sheet with a photo carousel, photo author links, opening hours, address, website, phone, and directions. Directions open Apple Maps.

## Run

The Bun TypeScript launcher handles physical iPhones/iPads, iOS simulators, and Mac:

```sh
./scripts/run                       # automatically select a target; watch by default
./scripts/run --targets             # list names, identifiers, runtimes, and states
./scripts/run -t simulator          # prefer a booted simulator, otherwise the newest runtime
./scripts/run -t "iPhone 17 Pro"     # select a named target (or pass its identifier)
./scripts/run -t mac                # run on this Mac
./scripts/run --no-watch            # build and launch once
```

With no `-t`/`--target`, `SWIFT_RUN_DEFAULT_TARGET` overrides the automatic choice and accepts the same names, identifiers, `simulator`, or `mac`. For example, `export SWIFT_RUN_DEFAULT_TARGET=simulator` makes simulator testing the default. An explicit target flag takes precedence. `--targets` marks the effective default with `*`.

Without an override, the script chooses a connected physical iOS device, then a booted simulator, then an available simulator, then My Mac. If several physical devices are connected, it uses the first listed by Xcode; select a name or identifier to override that choice. Duplicate simulator names prefer a booted instance, then the newest runtime; use an identifier to choose exactly. It supports Simulator and Xcode 27's Device Hub.

The script starts or reuses the search bridge, builds a Debug app, and installs and launches it on the target. Watching is enabled by default (`--watch`/`-w` also enable it). Saving changes in `Sources`, `Configuration`, or the shared Xcode project triggers an incremental build and restarts the app. Build errors leave the watcher running; fix the error and save again. Changes made during a build trigger another build afterward. Stop with Ctrl-C; the search bridge stays running in the background. Build logs are in `DerivedData/device/build.log`, `DerivedData/simulator/build.log`, or `DerivedData/mac/build.log`; the bridge log is `DerivedData/bridge.log`.

This is automatic rebuild/relaunch, so temporary UI state resets each time. It is not in-process Swift hot reload. [InjectionIII](https://github.com/johnno1962/InjectionIII) offers optional hot reload with additional setup and limitations, including changes to stored properties requiring a restart. It is not integrated into this app.

The launcher needs Xcode and Bun, with no added dependencies. It discovers the root `.xcodeproj`, uses its matching scheme, and reads the built app's bundle identifier. Device signing comes from the project; override it with `--team YOUR_TEAM_ID` or `MAPS_DEVELOPMENT_TEAM`. Complete the phone setup below before using a physical target.

For a manual Xcode launch, start the bridge:

```sh
Bridge/run.sh
```

It loads the existing scripts `.env` and `.env.local` without copying keys into the app or this repository. The script needs the exported `searchPlaces`, `placeDetails`, and `placePhoto` functions added alongside this app. Its usual `google-maps search` and `google-maps details` commands still work.

Open `PrivateMaps.xcodeproj`, select the **PrivateMaps** scheme, and run on an iPhone simulator or **My Mac**. The default bridge URL is `http://127.0.0.1:8787`. Allow location when prompted; if denied, search works in the visible map area and the sheet links to location settings.

`swift build` compiles the shared Swift source through Swift Package Manager. Run the bundled app through Xcode so location permission descriptions are available.

## Run on your iPhone

You can install development builds directly, without TestFlight. One-time setup:

1. Open `PrivateMaps.xcodeproj` in Xcode. Add your Apple account in **Xcode → Settings → Accounts** and select your team under **PrivateMaps → Signing & Capabilities**, with automatic signing enabled.
2. Connect your iPhone by USB, unlock it, and trust the Mac. Pair it in Xcode's device manager (**Devices and Simulators**, or **Device Hub** in Xcode 27).
3. Enable **Settings → Privacy & Security → Developer Mode** on the iPhone and complete its restart/confirmation. Run the **PrivateMaps** scheme on the phone once to complete signing and any device preparation. If iOS asks you to trust your developer profile, do so in **Settings → General → VPN & Device Management**.
4. After pairing, you can run wirelessly while the phone and Mac are on the same network; enable **Connect via network** if your Xcode version offers it. Keep the phone unlocked for installation and launch.

[Apple's Developer Mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) and [wireless device guide](https://help.apple.com/xcode/mac/current/en.lproj/dev3e2f4ee6d.html) cover the device setup.

Then `./scripts/run` automatically picks up your connected phone and watches for changes.

### Search bridge on the phone

Your Mac and phone need to be on the same network. When starting a bridge for a physical device, `run` listens on the LAN and requires `MAPS_BRIDGE_TOKEN`. It reuses an existing bridge; if that bridge only listens on loopback, stop it and restart with LAN access before testing search.

The bridge listens only on loopback by default. LAN access requires a token:

```sh
export MAPS_BRIDGE_TOKEN="$(openssl rand -hex 24)"
./scripts/run
```

Alternatively, launch the bridge manually with `Bridge/run.sh --host 0.0.0.0` after exporting the token. In the app, tap the sliders beside the search field to open **Search Connection**. Set the URL to `http://YOUR-MAC.local:8787` or `http://YOUR-MAC-IP:8787`, enter the token, test the connection, and save. Allow local network access when prompted. The token is saved in Keychain. Keep the token available for subsequent bridge launches; generate a new token and update the app if you want to rotate it. For use outside your LAN, put the bridge behind your private VPN or a private HTTPS endpoint.

## Bridge contract

`Bridge/service.ts` is the single-file service. `Bridge/run.sh` is its environment-loading launcher. You can override the scripts directory with `GOOGLE_MAPS_SCRIPTS_DIR`, or pass `--script /path/to/google-maps.ts`, `--host`, and `--port`.

| GET endpoint | Response |
| --- | --- |
| `/health` | `{ "status": "ok", "provider": "google-maps-script" }` |
| `/search?q=coffee&latitude=40.7&longitude=-74&radius=2500` | `{ "places": [...] }`, up to 20 Google Places objects |
| `/details?id=PLACE_ID` | A Google Places object with `photos` and `regularOpeningHours` |
| `/photo?name=places/PLACE_ID/photos/PHOTO_RESOURCE&width=1200` | Image bytes, with an image content type |

Requests use `Authorization: Bearer TOKEN` when a token is configured. Errors return `{ "error": "message" }` with an appropriate HTTP status. Photos retain their original `authorAttributions`; the app displays them with the image. The bridge proxies photo bytes so API keys and upstream redirect URLs stay off the device. Requests time out, invalid resource paths are rejected, and upstream error bodies are not exposed.

To move to an API later, implement these endpoints and change **Search Connection**. The client is in `Sources/App/PlacesClient.swift`.

The bridge does not persist or log searches, coordinates, or place data. Searches send the query and visible map center to Google; map tiles and device location display use Apple’s MapKit. The Google API key remains in your scripts environment. HTTP LAN traffic uses the same local network transport as the temporary bridge; a future remote API should use HTTPS.

## Verification

```sh
swift build
bun test Bridge/service.test.ts
xcodebuild -project PrivateMaps.xcodeproj -scheme PrivateMaps \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

`MapsFlowTests` is a live integration test for search → pin → details → loaded photo → clear search → connection check. Run it with the bridge active, an empty bridge token, the default app endpoint, and a simulator location set to a populated area. It makes real Google Places requests:

```sh
xcrun simctl location booted set 40.7308,-73.9973
xcodebuild -project PrivateMaps.xcodeproj -scheme PrivateMaps \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```
