# Tickytacky clients

Each folder is a **separate app**. Do not mix sources. Shared data later via Supabase.

| Folder | Platform | Product name | IDs |
|--------|----------|--------------|-----|
| [`ios/`](ios/) | iPhone, iPad, Mac | **Tickytacky** (Apple) | `app.tickytacky.ios` |
| [`web/`](web/) | Browser | **Tickytacky Web** | `app.tickytacky.web` |
| [`android/`](android/) | Android | **Tickytacky Android** | `app.tickytacky.android` |
| [`windows/`](windows/) | Windows | **Tickytacky Windows** | `app.tickytacky.windows` |

The Apple app in `ios/` is the shipping client. Web / Android / Windows are **prototypes** that sign in with **email** and sync Inbox tasks through the same Supabase project. Protocol: [`_shared/SYNC.md`](_shared/SYNC.md).
