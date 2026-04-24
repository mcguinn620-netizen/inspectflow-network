# Native shell stubs

These files are **not** compiled by the Lovable web sandbox. They are reference
implementations for the iOS (CarPlay) and Android (Android Auto) projects you
generate locally with Capacitor.

## After `npx cap add ios`

```
mkdir -p ios/App/App/CarPlay
cp native/ios/CarPlaySceneDelegate.swift ios/App/App/CarPlay/
```

Then in Xcode:
1. Add the file to the App target.
2. Update `Info.plist` with the `UIApplicationSceneManifest` block shown at
   the top of the Swift file.
3. Apply for the CarPlay entitlement (Apple developer portal) and add it
   to the App target's Signing & Capabilities.

## After `npx cap add android`

```
mkdir -p android/app/src/main/java/app/lovable/c4a81c228a3d4381bec7340e222a48cb/car
cp native/android/InspectorCarAppService.java \
  android/app/src/main/java/app/lovable/c4a81c228a3d4381bec7340e222a48cb/car/
```

Then update `android/app/build.gradle` and `AndroidManifest.xml` per the
comment block at the top of the Java file.

See [`../docs/native/CARPLAY_CONTRACT.md`](../docs/native/CARPLAY_CONTRACT.md)
for the JSON shape both shells consume from Supabase.
