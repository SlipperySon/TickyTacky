# Tickytacky Android

Native Android prototype. **Not** the Apple app (`apps/ios/`) and **not** a shared Flutter/RN project.

- Display name: **Tickytacky Android**
- Application ID: `app.tickytacky.android`
- Sage platform stripe so it is obvious this is the Android client

Open `apps/android` in Android Studio (Koala / Ladybug or newer) and run the `app` module. If Gradle Wrapper is incomplete on first clone, let Android Studio generate it (`gradle/wrapper/gradle-wrapper.jar`).

Local sample Today list only. Supabase later.

Email sign-in + Inbox task sync against the hosted project. See [`../_shared/SYNC.md`](../_shared/SYNC.md). Needs `INTERNET`.
