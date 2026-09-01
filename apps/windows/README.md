# Tickytacky Windows

Native Windows (WPF / .NET 8) prototype. **Not** the Apple Mac target in `apps/ios/`.

- Display name: **Tickytacky Windows**
- Assembly: `Tickytacky.Windows`
- Application id: `app.tickytacky.windows`
- Kraft platform stripe so it is obvious this is the Windows client

```powershell
cd apps/windows
dotnet run
```

Requires Windows + .NET 8 SDK. This folder will not run on macOS.

Local sample Today list only. Supabase later.

Email sign-in + Inbox task sync against the hosted project. See [`../_shared/SYNC.md`](../_shared/SYNC.md).
