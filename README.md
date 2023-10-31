# TypeaheadAI

This is the repo containing the Swift front-end code for TypeaheadAI.

## Distribution

We are distributing the app outside of the App Store, so there are some limitations and extra hoops.

First, we need to provision Developer ID certificates. Under `Targets > TypeaheadAI > Signing & Capabilities`, we can leave the `Automatically manage signing` and click on `Team > Jeff Hara > Add an Account > Manage Certificates` to make changes.

Then, in the Keychain Access, we can validate that the "Developer ID Application: Jeff Hara (TZA...)" is in the My Certificates tab.

Not sure about the order of events, but I can get the team ID with this command:

```
➜ xcrun altool --list-providers -u "jhara1418@gmail.com" -p "ygeu-eaej-xuoc-xoxl"
ProviderName ProviderShortname PublicID                             WWDRTeamID
------------ ----------------- ------------------------------------ ----------
Jeff Hara    TZA789GZFT        3367bf6e-1091-4f2e-a9b5-87c0cf07b660 TZA789GZFT
```

We can export the app using XCode, and we can codesign the app with this:


```
➜ codesign --force --deep --options=runtime --timestamp --sign "Developer ID Application: Jeff Hara (TZA789GZFT)" Exports/TypeaheadAI\ 2023-10-30\ 16-00-29/TypeaheadAI.app
Exports/TypeaheadAI 2023-10-30 16-00-29/TypeaheadAI.app: replacing existing signature
```

Then, we can create the DMG file using create-dmg.

```
# install create-dmg (only once)
➜ sudo npm install --global create-dmg

# run create-dmg
➜ create-dmg Exports/TypeaheadAI\ 2023-10-30\ 16-00-29/TypeaheadAI.app --overwrite
ℹ Code signing identity: Developer ID Application: Jeff Hara (TZA789GZFT)
✔ Created “TypeaheadAI 1.23.dmg”
```

Finally, we can notarize the DMG file with:

```
➜ xcrun notarytool submit TypeaheadAI\ 1.23.dmg --apple-id jhara1418@gmail.com --password ygeu-eaej-xuoc-xoxl --team-id TZA789GZFT --keychain-profile "TypeaheadAI" --wait
Conducting pre-submission checks for TypeaheadAI 1.23.dmg and initiating connection to the Apple notary service...
Submission ID received
  id: 1ea985ab-97f6-4eaf-8dc8-00289c85fe2b
Upload progress: 100.00% (6.10 MB of 6.10 MB)
Successfully uploaded file
  id: 1ea985ab-97f6-4eaf-8dc8-00289c85fe2b
  path: /Users/jeffhara/workspace/TypeaheadAI/TypeaheadAI 1.23.dmg
Waiting for processing to complete.
Current status: Accepted............
Processing complete
  id: 1ea985ab-97f6-4eaf-8dc8-00289c85fe2b
  status: Accepted
```

Now, the DMG file should be ready for distribution.

If the notarization fails, we can check the logs with:

```
xcrun notarytool log --keychain-profile TypeaheadAI <id>
```


