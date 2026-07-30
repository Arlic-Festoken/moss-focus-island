# Moss iCloud sync

Moss uses `CKSyncEngine` with the current Apple ID's private CloudKit database.
The local JSON database remains the source used by the UI and is written
atomically before a cloud sync is scheduled.

## Data safety rules

- iCloud sync is opt-in and disabled by default.
- Local saves never wait for the network.
- Disabling sync never deletes local data or CloudKit records.
- Signing out or switching Apple IDs never deletes the local database.
- Every CloudKit entity has a stable UUID record name.
- Deletions are sent as explicit record deletions rather than inferred from an
  empty snapshot.
- Conflicts compare the user's modification timestamp. A late upload from an
  older offline device does not automatically overwrite a newer edit.
- Sync-engine state and CloudKit system fields are persisted separately in
  `cloud-sync-state.json`, with an atomic backup.
- Each record payload is capped below CloudKit's per-record limit. Oversized
  records remain local and surface an error instead of being truncated.

## CloudKit schema

- Container: `iCloud.com.zhikanghuang.moss`
- Database: private
- Zone: `MossDataV1`
- Record type: `MossEntity`
- Encrypted fields: `kind`, `payload`, `userModificationDate`

Synced entity kinds are projects, tasks, sessions, interruptions, reflections,
daily snapshots, plans, and journal records. Custom background images remain
local.

## Apple Developer setup

CloudKit requires an Apple Developer Program team and a provisioning profile
that authorizes the bundle ID and container.

1. Register `com.zhikanghuang.moss` in Certificates, Identifiers & Profiles.
2. Enable iCloud and CloudKit for that App ID.
3. Create or associate `iCloud.com.zhikanghuang.moss`.
4. Create an Apple Development certificate and provisioning profile.
5. Install the certificate and profile on the build Mac.
6. Build with:

   ```bash
   MOSS_ENABLE_ICLOUD_ENTITLEMENTS=1 \
   MOSS_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" \
   ./scripts/build-app.sh
   ```

The build script intentionally refuses to attach iCloud entitlements to an
ad-hoc signature. An ad-hoc build continues to work as a local-only app and the
settings screen reports that the installation lacks iCloud permission.

## Verification sequence

1. Preserve a copy of `moss-data.json` and its backup.
2. Install the signed build on the first Mac and enable iCloud in Moss settings.
3. Confirm the status reaches `已同步`.
4. Inspect the development environment in CloudKit Console while acting as the
   same iCloud account.
5. Install on a second Apple device using the same Apple ID.
6. Verify create, edit, delete, offline edit, concurrent edit, sign-out, and
   account-switch behavior.
7. Promote the CloudKit development schema to production only after the
   two-device matrix passes.

Do not promote the schema or ship an iCloud-enabled build based only on a
successful compile.
