# Maps

Monorepo for the private maps app and its search bridge.

- `app-ios/` — SwiftUI app for iOS 17+ and macOS 14+
- `server/` — Bun server that proxies Google Places search

```sh
npm start                 # bridge, usually http://127.0.0.1:8787
npm run run:ios           # build and launch the iOS app
bun test                  # bridge proxy tests
```

Development selects the bridge with `MAPS_SERVER_URL`, or with `MAPS_SERVER_HOST` and `MAPS_SERVER_PORT`. `npm run run:ios` passes that URL into the app. Device setup, the bridge contract, and Xcode details are in [app-ios/README.md](app-ios/README.md).
