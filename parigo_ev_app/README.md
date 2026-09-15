# Parigo EV

The Android and iOS apps share the Flutter experience: customer ride booking,
driver location updates, administration, payments, maps, and profile uploads.

## iOS project

The iOS target is in `ios/Runner.xcworkspace` and supports iOS 15 or later.
Open the workspace (not `Runner.xcodeproj`) after running `flutter pub get`.

The iOS target has the native declarations used by the app:

- Google Maps SDK startup and its `GMSApiKey` value.
- Camera, photo-library, foreground/background location, and background-refresh
  usage descriptions.
- Background refresh registration for the administrator booking service.

Before distributing a build, complete the account-owned service setup below.
These values cannot be safely fabricated from the Android configuration.

1. In Firebase, register the iOS bundle ID `com.parigoev.parigoEvApp` in the
   same Firebase project as Android and download `GoogleService-Info.plist`.
   Add it to the Runner target in Xcode. This enables Firebase Auth,
   Crashlytics, and Analytics.
2. Enable iOS phone authentication in Firebase. Upload the APNs auth key and
   add the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` as a URL scheme
   on the Runner target. This is required for OTP sign-in on physical iPhones.
3. In Google Cloud, allow the Maps SDK for iOS key used in
   `ios/Runner/Info.plist` for the iOS bundle ID above. The Directions/Places
   APIs also need to remain enabled for search and routing.
4. Select the Apple Development team and provisioning profile in Xcode before
   installing on a device. Enable Background Fetch in Signing & Capabilities if
   the admin background refresh feature is needed.

Apple does not allow a persistent five-second polling process after an app is
suspended. The existing admin polling works while the app is foregrounded and
can receive occasional system-scheduled refreshes in the background. For
reliable booking alerts while the app is closed, the next iOS milestone is an
APNs/FCM push-notification flow, using the APNs key from the Apple Developer
account and the Firebase registration from step 1.

To validate a simulator build:

```sh
flutter pub get
flutter build ios --simulator --no-codesign
```
