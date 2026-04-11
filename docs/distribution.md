# Distribution — Code Signing & Notarization

How to configure code signing for mallcore-sim releases on macOS and Windows.

---

## Overview

macOS requires apps distributed outside the App Store to be signed with a
Developer ID certificate and notarized by Apple. The CI pipeline in
`.github/workflows/export.yml` handles this automatically when the required
secrets are configured. Without secrets, the pipeline still produces unsigned
builds.

---

## Required GitHub Actions Secrets

Configure these in **Settings > Secrets and variables > Actions** for the repository.

| Secret | Description | How to Obtain |
|---|---|---|
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID | [Apple Developer Account](https://developer.apple.com/account) > Membership Details |
| `APPLE_ID` | Apple ID email used for notarization | The email address of the Apple Developer account |
| `APPLE_PASSWORD` | App-specific password for notarization | [appleid.apple.com](https://appleid.apple.com/) > Sign-In and Security > App-Specific Passwords |
| `MACOS_CERTIFICATE` | Base64-encoded `.p12` Developer ID certificate | See "Exporting the Certificate" below |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` file | Set during `.p12` export from Keychain Access |

---

## Generating an App-Specific Password

Apple requires an app-specific password (not your account password) for
notarization via `notarytool`.

1. Go to [appleid.apple.com](https://appleid.apple.com/)
2. Sign in with the Apple ID that holds the Developer membership
3. Navigate to **Sign-In and Security > App-Specific Passwords**
4. Click **Generate an app-specific password**
5. Label it (e.g., "mallcore-sim-ci") and copy the generated password
6. Store this as the `APPLE_PASSWORD` secret in GitHub

---

## Exporting the Certificate

The CI pipeline expects a base64-encoded PKCS#12 (`.p12`) file containing the
"Developer ID Application" certificate and its private key.

1. Open **Keychain Access** on macOS
2. Find the certificate named **Developer ID Application: Your Name (TEAM_ID)**
3. Right-click > **Export Items...** > save as `.p12` with a strong password
4. Base64-encode it for GitHub:

```bash
base64 -i developer_id_application.p12 | pbcopy
```

5. Paste the clipboard contents as the `MACOS_CERTIFICATE` secret
6. Store the `.p12` password as `MACOS_CERTIFICATE_PASSWORD`

Do NOT commit the `.p12` file to the repository.

---

## How the CI Pipeline Works

When a version tag (`v*`) is pushed, the export workflow:

1. **Exports** the Godot project as a macOS `.app` bundle
2. **Imports the certificate** into a temporary keychain (if `MACOS_CERTIFICATE` is set)
3. **Codesigns** the `.app` with `codesign --deep --options runtime` (if `APPLE_TEAM_ID` is set)
4. **Notarizes** via `xcrun notarytool submit --wait` (if all Apple secrets are set)
5. **Staples** the notarization ticket to the `.app` with `xcrun stapler staple`
6. **Uploads** the signed, notarized `.zip` as a release artifact

Each step is conditional — missing secrets skip that step gracefully, producing
an unsigned build instead of failing the pipeline.

---

## Verifying a Signed Build Locally

After downloading a release artifact:

```bash
# Check code signature
codesign --verify --verbose MallcoreSim.app

# Check notarization staple
xcrun stapler validate MallcoreSim.app

# Check Gatekeeper acceptance
spctl --assess --type execute --verbose MallcoreSim.app
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `notarytool` returns "Invalid credentials" | Wrong `APPLE_ID` or `APPLE_PASSWORD` | Regenerate the app-specific password |
| `notarytool` returns "Team ID not found" | `APPLE_TEAM_ID` doesn't match the certificate | Verify Team ID at developer.apple.com |
| Codesign fails with "no identity found" | Certificate not imported or wrong format | Re-export the `.p12` and re-encode as base64 |
| Notarization rejected with hardened runtime errors | Missing `--options runtime` in codesign | Already set in CI — check for local build overrides |
| Staple fails with "not found in ticket database" | Notarization hasn't completed | Wait and retry; `notarytool submit --wait` handles this |
| Unsigned builds still produced | Secrets not configured | Check repository Settings > Secrets |

---

## Security Notes

- Never commit certificates, passwords, or Apple credentials to the repository
- App-specific passwords can be revoked at any time from appleid.apple.com
- The temporary keychain created during CI is scoped to the runner and discarded after the job
- The `.p12` file is decoded in-memory and deleted immediately after import

---

# Windows Code Signing

## Overview

Windows SmartScreen and antivirus tools flag unsigned executables. The CI
pipeline in `.github/workflows/export.yml` signs the Windows build with
`signtool` when the required secrets are configured. Without secrets, the
pipeline still produces unsigned builds.

---

## Required GitHub Actions Secrets

Configure these in **Settings > Secrets and variables > Actions** for the repository.

| Secret | Description | How to Obtain |
|---|---|---|
| `WINDOWS_CERT` | Base64-encoded `.pfx` code signing certificate | See "Obtaining a Certificate" below |
| `WINDOWS_CERT_PASSWORD` | Password used when exporting the `.pfx` file | Set during `.pfx` export |

---

## Obtaining a Certificate

Windows code signing requires a certificate from a trusted Certificate
Authority (CA). Common providers include DigiCert, Sectigo, and GlobalSign.

### Option A: Purchase from a CA (recommended for distribution)

1. Purchase an Authenticode code signing certificate from a CA
2. Complete identity verification as required by the CA
3. Export the certificate as a `.pfx` (PKCS#12) file with a strong password
4. Base64-encode it for GitHub:

```bash
# macOS / Linux
base64 -i code_signing.pfx | pbcopy

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("code_signing.pfx")) | Set-Clipboard
```

5. Paste the encoded string as the `WINDOWS_CERT` secret
6. Store the `.pfx` password as `WINDOWS_CERT_PASSWORD`

### Option B: Self-signed certificate (for testing only)

A self-signed certificate will not be trusted by Windows SmartScreen but can
validate that the signing pipeline works.

```powershell
$cert = New-SelfSignedCertificate `
  -Type CodeSigningCert `
  -Subject "CN=Mallcore Sim Dev" `
  -CertStoreLocation Cert:\CurrentUser\My `
  -NotAfter (Get-Date).AddYears(3)

$password = ConvertTo-SecureString -String "YourPassword" -Force -AsPlainText

Export-PfxCertificate `
  -Cert $cert `
  -FilePath code_signing_test.pfx `
  -Password $password
```

Then base64-encode and store as described above.

Do NOT commit the `.pfx` file to the repository.

---

## How the CI Pipeline Works

When a version tag (`v*`) is pushed, the export workflow:

1. **Exports** the Godot project as a Windows `.exe` on a `windows-latest` runner
2. **Imports the certificate** into the runner's certificate store (if `WINDOWS_CERT` is set)
3. **Signs** the `.exe` with `signtool sign /fd sha256 /tr http://timestamp.digicert.com /td sha256`
4. **Verifies** the signature with `signtool verify /pa`
5. **Uploads** the signed `.exe` as a release artifact

Each step is conditional — missing secrets skip the signing steps gracefully,
producing an unsigned build instead of failing the pipeline.

---

## Verifying a Signed Build

After downloading a release artifact:

```powershell
# Check digital signature (PowerShell)
Get-AuthenticodeSignature .\MallcoreSim.exe

# Or right-click the .exe in Explorer > Properties > Digital Signatures tab
```

A valid signature shows "This digital signature is OK" with the signer name
matching the certificate subject.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `signtool` returns "No certificates were found" | Certificate not imported or wrong format | Re-export the `.pfx` and re-encode as base64 |
| `signtool` returns "SignTool Error: An unexpected internal error has occurred" | Password mismatch | Verify `WINDOWS_CERT_PASSWORD` matches the `.pfx` export password |
| SmartScreen still warns after signing | Self-signed or low-reputation cert | Use a CA-issued EV or standard code signing certificate |
| Timestamping fails | Timestamp server unreachable | Retry; the DigiCert timestamp server is generally reliable |
| `signtool.exe` not found on runner | Windows SDK not pre-installed | `windows-latest` runners include the SDK; report if missing |
| Unsigned builds still produced | Secrets not configured | Check repository Settings > Secrets |
