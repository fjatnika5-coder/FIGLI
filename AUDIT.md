# AUDIT TEKNIS — ACM System (Likes, Animation Sync, Carry, Clone, Favorites, TipJar)

Tanggal: 2026-07-14. Sumber: 14 file yang dikirim via chat (8 server, 3 shared/module, 3 client).
Semua script final ada di folder `src/` repo ini, path pemasangan tertulis di header tiap file.

---

## A. RINGKASAN EKSEKUTIF

**Kondisi sebelum:** Sistem sudah pernah dipatch (versi "PATCHED"/V5/v6) dan fondasinya lumayan:
sudah ada rate limit, lock, cleanup connection per pasangan carry, dan BindToClose.
Namun masih ada 4 bug kelas data-loss / logic-breaking, beberapa leak kecil yang menumpuk
seumur server, satu HTTP call per buka panel, dan sejumlah dead code.

**Masalah paling berat:**
1. **Favorites**: kalau load DataStore gagal, sesi tetap boleh toggle + save → **favorit lama
   tertimpa map kosong** (data loss permanen).
2. **CarryServer**: `error("limit_transfer")` di dalam pcall menghasilkan string berprefix
   `"script:line: limit_transfer"`, sehingga perbandingan `err == "limit_transfer"` **tidak pernah
   match** — cabang notifikasi limit transfer mati total, dan path script bocor ke client.
3. **TipJar**: key antrian global save memakai `tostring(store)` yang tidak dijamin unik per
   DataStore object → entri Raised dan Donated player yang sama bisa **saling menimpa** di queue.
4. **TipJar**: donasi yang terjadi sebelum data player selesai load membuat `sessionData` palsu,
   lalu loader **menimpanya** dengan data lama → delta donasi hilang dari statistik.

**Penyebab lag / beban:** HTTP followers tanpa cache (tiap buka panel = 1 request keluar),
`GetFriendsAsync` full pagination per buka panel (dibiarkan, client-side), Heartbeat client
yang jalan penuh tiap frame untuk monitor jarak dan status label yang tidak pernah ada,
`ContentProvider:PreloadAsync` di server (tidak berguna di server, buang budget).

**Penyebab memory leak:** tabel `slotByCarrier`/`lockMap`/`detachGuard` per-UserId tidak semua
dibersihkan saat player keluar; `pendingPrompts` client tidak pernah dihapus; debug mode client
membuat koneksi Heartbeat baru setiap toggle tanpa disconnect; `followerCache` (baru) diberi prune.

**Penyebab exploit:** relatif kecil — validasi sudah lumayan. Ditambah: rate limit untuk
`UpdateAnimation`/`RequestSync`/`UpdateAnimationSpeed` (sebelumnya bisa spam → LoadAnimation
berulang di server), NaN guard di speed, dan speed clamp client disamakan dengan server.

**Keputusan:** PATCH terarah, bukan rebuild. Arsitektur existing (folder EventsACMS, remote
per fitur, _G untuk API client) dipertahankan karena ada script lain (FastBar, TipJar UI) yang
tidak dikirim dan bergantung padanya. Rebuild framework akan memutus kontrak itu tanpa bisa
diverifikasi.

**Kondisi setelah:** Semua temuan CRITICAL/HIGH diperbaiki, dead code dibuang, print debug
dibersihkan, cleanup PlayerRemoving lengkap, format data DataStore **tidak berubah** (tidak
perlu migrasi).

---

## B. TEMUAN BERDASARKAN PRIORITAS

### CRITICAL

| # | Lokasi | Masalah | Bukti | Perbaikan |
|---|--------|---------|-------|-----------|
| C1 | Favorites.server.lua `ensureLoaded`/`save` | Load gagal → `cache = {}` + `loadLock = true` permanen; toggle berikutnya set `dirty`, autosave menulis map kosong menimpa data asli | Terbukti dari source: tidak ada flag load-sukses; `save()` hanya cek `dirty` | Flag `loadOk[userId]`; load retry 3×; kalau tetap gagal → sesi read-only (toggle & save ditolak, warn sekali) |
| C2 | CarryServerHandler `startCarry` + handler `Response` | `error("limit_transfer")` dalam pcall → err = `"ServerScriptService.X:NNN: limit_transfer"`; perbandingan `tostring(err2) == "limit_transfer"` selalu false; reason yang dikirim ke client berisi path script | Terbukti: `error(msg)` level default menambah prefix posisi | Semua `error(code, 0)` (level 0 = tanpa prefix); mapping reason client diperluas untuk kode baru (`too_far`, `busy_target`, dst) |
| C3 | TipJarCoreServer `queueGlobalSave2` | `storeKey = tostring(store).."_"..userId` — `tostring` DataStore object tidak dijamin unik per store → entri Raised & Donated user sama bisa share key dan saling menimpa di queue | Plausible-tinggi dari source (tergantung representasi tostring); risiko data leaderboard hilang | Key eksplisit `"raised_"..userId` / `"donated_"..userId` via parameter `keyPrefix` |
| C4 | TipJarCoreServer `applyDonation2` vs `processLoadQueue2` | Donasi sebelum load selesai membuat `sessionData` berisi delta saja; loader kemudian `sessionData[uid] = playerData` (menimpa) → delta hilang; sebaliknya kalau save jalan sebelum load, nilai lama tertimpa delta parsial | Terbukti dari urutan kode | Loader **merge** delta pending ke data hasil load; `savePlayerData` menolak menulis sebelum `dataLoaded[uid]` |

### HIGH

| # | Lokasi | Masalah | Perbaikan |
|---|--------|---------|-----------|
| H1 | ACM_Backend_Stats `GetPlayerStats` | Rate limit mengembalikan data palsu `{likes=0, hasLiked=false}` → client menimpa cache dengan nilai salah (buka panel 2× dalam 2 detik = angka nol) | Return `nil` saat rate-limited/invalid; client sudah `if data then` → cache lama dipertahankan |
| H2 | ACM_Backend_Stats | HTTP followers tanpa cache: 1 request roproxy per invoke | Cache per target: TTL 300s sukses / 60s gagal + prune |
| H3 | AvatarContextMenu (client) tombol Like | Update optimistik tanpa cooldown; server drop request < 3s → UI dan DataStore desync permanen sampai refetch | Cooldown client 3s (`LIKE_COOLDOWN`) sebelum update optimistik + fire |
| H4 | CarryServerHandler `detachPair` | Body antara `acquireLock`/`releaseLock` tanpa pcall — error apa pun (part destroyed dsb.) → lock nyangkut, semua aksi carry player itu deadlock 5s per operasi | Bungkus pcall, release selalu jalan, state map dipulihkan on error; sama untuk `transferPassengersToAtomic` dan `reindexSlots` |
| H5 | CarryServerHandler | Leak per-UserId: `slotByCarrier` (tabel kosong tersisa), `lockMap`, `detachGuard`, `savedProps`, `savedHum` tidak dibersihkan di PlayerRemoving | Cleanup lengkap di PlayerRemoving + `slotByCarrier[uid] = nil` saat map carrier kosong |
| H6 | AnimationServer | `ContentProvider:PreloadAsync` di **server** — tidak berpengaruh ke client, hanya buang waktu/budget | Dihapus (preload asset adalah tugas client) |
| H7 | AnimationServer | `UpdateAnimation`/`RequestSync`/`UpdateAnimationSpeed` tanpa rate limit → spam client memicu BFS + LoadAnimation berulang di server | Rate limit per player per aksi (0.25s / 0.5s / 0.2s) + NaN guard speed; cleanup di PlayerRemoving |
| H8 | AvatarContextMenu `showPanel` | `State.isRemoteView = isRemote or false` — `isRemote` variabel **tidak terdefinisi** (selalu nil); parameter ke-4 `_G.ACM_API.showPanel` diabaikan | Parameter `isRemote` ditambahkan ke signature |
| H9 | AvatarContextMenu debug mode | Setiap toggle ON membuat koneksi `RunService.Heartbeat` baru tanpa disconnect → leak + beban per frame | Debug system dihapus (termasuk `_G.ACM_API.toggleDebug`) |

### MEDIUM

| # | Lokasi | Masalah | Perbaikan |
|---|--------|---------|-----------|
| M1 | ACM_Backend_Stats like/unlike | Set/Remove history sukses tapi Increment gagal → count & status desync permanen | Rollback history saat increment gagal (dua arah) |
| M2 | ACM_Backend_Stats playtime | Hanya disave saat leave/shutdown — crash server = progress hilang | Autosave tiap 120 detik dari loop playtime yang sudah ada |
| M3 | AnimationsUI vs AnimationServer | Clamp speed client 0.1–4.0, server 0.1–3.0 → di atas 3.0 UI bohong | Client disamakan 0.1–3.0 (`SPEED_MIN/MAX`) |
| M4 | AnimationsUI `rebuildList` | `string.find(name, query)` mode pattern — query berisi karakter magic (`(`, `?`, `%`) bikin error/hasil salah; nama pose "Ready ?" ada di data | `string.find(..., 1, true)` plain text |
| M5 | AnimationsUI `updateScale` | Width boost mengalikan `Main.Size` saat itu — kalau terpanggil 2× ukuran menggandakan diri | Basis `originalMainSize` disimpan sekali |
| M6 | AnimationsUI | `require(ReplicatedStorage:WaitForChild("Icon"))` — hasil tidak pernah dipakai; kalau module tidak ada, `WaitForChild` hang selamanya dan seluruh UI mati | Dihapus |
| M7 | AvatarContextMenu `setupStatusMonitor` | Loop Heartbeat mencari TextLabel "Status" yang **tidak pernah dibuat** — dead code jalan terus | Dihapus |
| M8 | AvatarContextMenu `setupDistanceMonitor` | Jalan tiap frame, body-nya 90% dikomentari | Disederhanakan: throttle 0.25s, hanya auto-close saat HRP hilang |
| M9 | AvatarContextMenu | `pendingPrompts` tidak pernah dibersihkan setelah dijawab/expired; `DataCache` tidak dibersihkan saat player keluar | Clear saat accept/deny/timeout/expire; `DataCache[uid]` & `pendingPrompts[uid]` dihapus di PlayerRemoving |
| M10 | AvatarContextMenu | Dead code: `pruneCarriedIds`, `findCharacterModel`, `getHumanoid`, `carriedIndex`, `COLOR_GOLD/HIGHLIGHT`, override sound ganda (open sound + click sound bunyi dobel per buka panel) | Dihapus; sparkle effect dipertahankan (digabung ke `highlightTarget`) |
| M11 | Favorites | Print debug banyak + `print("[License] Verification successful …")` (bukan verifikasi apa pun, hanya print menyesatkan) | `DEBUG=false`, license print dihapus |
| M12 | Favorites | Loader tidak cek player masih ada setelah GetAsync → entry cache stale kalau player keluar saat load | Cek `GetPlayerByUserId` setelah load, bersihkan kalau sudah keluar |
| M13 | TipJarGetGamepass | Print `[DEBUG]` + warn spam "requesting too fast" | Dihapus / silent return |

### LOW

- **Shared/Animations**: entri duplikat — "Hip Hop 1" = "Hip Hop Arms Dance" (id sama `76240950459288`), dua entri "Last Forever" berbeda id. Server otomatis dedupe by id; UI menampilkan keduanya. **Tidak diubah** (data konten = keputusan pemilik game).
- **ACM_Server_Clone**: `getAliveHumanoid` polling 0.1s selama max 3s per request — bisa event-driven, tapi dengan cooldown 3s bebannya kecil. Tidak diubah.
- **ProximityPrompt fork**: pakai `wait(0.2)` API lama; script fork resmi Roblox, jalan normal. Tidak diubah.
- **AnimationServer sync heartbeat**: set `TimePosition` follower tiap koreksi drift — bisa terlihat "jump" kecil > toleransi 0.08s. Perilaku desain, dipertahankan; body per-player kini dibungkus pcall supaya track yang keburu destroyed tidak melempar error tiap frame.
- **GetStats `followers`** bertipe campur (number atau string "N/A") — dipertahankan karena client sudah menghandle; ubah = ubah kontrak remote.

---

## C. SARAN (di luar yang sudah diperbaiki)

**Sudah diperbaiki:** semua item B di atas kecuali yang bertanda "Tidak diubah".

**Disarankan (belum diterapkan):**
- Pindahkan `_G.ACM_STATE`/`_G.ACM_API`/`_G.AnimationsUI` ke ModuleScript bersama — butuh file FastBar & TipJar UI yang belum dikirim.
- Preload animasi di **client** (LocalScript kecil yang PreloadAsync daftar dari `Shared/Animations`).
- Likes: pertimbangkan `MemoryStoreService` untuk counter panas kalau player ramai (IncrementAsync DataStore per like cukup boros budget).
- Ganti teks announcement TipJar yang mengandung kata kasar ("Tangina") — berisiko moderasi Roblox. Tidak kuubah karena itu konten gameplay.

**Perlu konfirmasi:** apakah ada script lain yang memakai `_G.ACM_API.toggleDebug` (sudah dihapus).

**Tidak cukup source / perlu runtime test:** FastBar, TipJar UI (client), modul `Icon`, GUI structure `AnimationsUI` (MainFrame dsb.), `OpenTipJar`/`BackToACM` (diasumsikan BindableEvent di `EventsACMS`), Tip Jar tool di karakter.

---

## D. FULL SCRIPT FINAL

Semua di folder `src/` (path pemasangan Explorer ada di header tiap file):

- `src/ServerScriptService/ACM_Backend_Stats.server.lua`
- `src/ServerScriptService/AnimationServer.server.lua`
- `src/ServerScriptService/CarryServerHandler.server.lua`
- `src/ServerScriptService/Favorites.server.lua`
- `src/ServerScriptService/GiftDonation/TipJarCoreServer.server.lua`
- `src/ServerScriptService/GiftDonation/TipJarGetGamepass.server.lua`
- `src/StarterPlayerScripts/AvatarContextMenu.client.lua`
- `src/StarterGui/AnimationsUI.client.lua`

## E. DAFTAR FILE

**DIGANTI (8):** semua file di bagian D.

**DITAMBAH:** tidak ada script baru (hanya AUDIT.md ini).

**DIHAPUS:** tidak ada script yang dihapus utuh; yang dihapus adalah bagian dalam file
(debug mode ACM, status monitor, preload server, license print, dead helpers).

**TIDAK DIUBAH (pakai versi existing):**
- `ServerScriptService/ACM_Server_Clone` (sudah aman: validasi, rate limit, cleanup)
- `ServerScriptService/GiftDonation/GamepassRegistry` (ModuleScript)
- `ReplicatedStorage/Shared/Animations`, `ReplicatedStorage/Shared/Poses`
- `ReplicatedStorage/CarryBlueprints`
- LocalScript ProximityPrompt custom

## F. STRUKTUR EXPLORER FINAL

```
ServerScriptService
├─ ACM_Backend_Stats            (Script)   ← diganti
├─ AnimationServer              (Script)   ← diganti
├─ CarryServerHandler           (Script)   ← diganti
├─ Favorites                    (Script)   ← diganti
├─ ACM_Server_Clone             (Script)   ← tetap
└─ GiftDonation                 (Folder)
   ├─ TipJarCoreServer          (Script)   ← diganti
   ├─ TipJarGetGamepass         (Script)   ← diganti
   └─ GamepassRegistry          (ModuleScript) ← tetap

ReplicatedStorage
├─ EventsACMS                   (Folder — dibuat/dilengkapi otomatis oleh server)
│  ├─ GetPlayerStats            (RemoteFunction)
│  ├─ ToggleLike                (RemoteEvent)
│  ├─ SendLikeNotification      (RemoteEvent)
│  ├─ RequestSync               (RemoteEvent)
│  ├─ UpdateAnimation           (RemoteEvent)
│  ├─ UpdateAnimationSpeed      (RemoteEvent)
│  ├─ FavoritesGet              (RemoteFunction)
│  ├─ FavoritesSet              (RemoteEvent)
│  ├─ OpenTipJar                (BindableEvent — dari sistem TipJar UI)
│  └─ BackToACM                 (BindableEvent — dari sistem TipJar UI)
├─ CarryRemote                  (RemoteEvent)
├─ CloneAvatarRemote            (RemoteEvent)
├─ Remotes                      (Folder — TipJar)
│  ├─ ChatMessage               (RemoteEvent)
│  ├─ RequestDonation           (RemoteEvent)
│  ├─ DonateRobux               (RemoteEvent)
│  └─ GetGamePasses             (RemoteEvent)
├─ Shared                       (Folder)
│  ├─ Animations                (ModuleScript)
│  └─ Poses                     (ModuleScript)
└─ CarryBlueprints              (ModuleScript)

StarterPlayer/StarterPlayerScripts
└─ AvatarContextMenu            (LocalScript) ← diganti

StarterGui
└─ AnimationsUI (ScreenGui — struktur existing)
   └─ LocalScript               ← diganti (src/StarterGui/AnimationsUI.client.lua)
```

Atribut yang dipakai: `Player.syncedPlayerId` (number), `Player.currentAnimationId` (string),
`Player.currentAnimationSpeed` (number), `LikeButton.IsLiked` (bool, UI lokal).

## G. MIGRATION GUIDE

1. **Backup** place (Save As / version history) + catat nama DataStore existing.
2. Disable script lama (jangan hapus dulu): set `Disabled = true`.
3. Paste isi file `src/` ke script yang sesuai (atau replace via Rojo kalau dipakai).
4. Tidak ada remote yang dihapus/di-rename — client lama tetap kompatibel.
5. Cek `EventsACMS` berisi semua remote di bagian F setelah server start.
6. **Format DataStore tidak berubah** — tidak ada migrasi data. Store yang dipakai tetap:
   `ACM_Likes_Data_v1`, `ACM_Likes_History_v1`, `ACM_Playtime_Data_v1`, `PlayerLikes` (read-only legacy),
   `AnimationFavorites_v1`, `DonatedRaised`, `TipJar_Global_Raised`, `TipJar_Global_Donated`.
7. Test Studio Solo → Local Server 2 player → private server.
8. Rollback: enable kembali script lama (langkah 2), tidak ada perubahan data yang perlu di-undo.

## H. TEST CHECKLIST

- [ ] Join / leave / rejoin — leaderstats muncul, playtime lanjut, favorit termuat.
- [ ] Respawn 5× + reset character — track animasi bersih, panel ACM tertutup, carry lepas.
- [ ] Spam klik tombol Like (>5×/detik) — hanya 1 toggle per 3s, UI tidak desync setelah reopen panel.
- [ ] Buka/tutup panel ACM 20× — FOV kembali normal, tidak ada Highlight/GUI tersisa (cek Explorer).
- [ ] Buka panel 2× dalam 2 detik — angka stats tidak berubah jadi 0 (cache dipertahankan).
- [ ] Carry: request → accept/deny/timeout; Multi 8 slot; transfer (carry orang yang sedang menggendong); Stop; X shortcut; mati saat digendong; carrier leave.
- [ ] Limit transfer (grup penuh) — notifikasi "Cannot transfer (Group full)" muncul (dulu tidak pernah).
- [ ] Sync dance: leader ganti dance, follower join mid-dance, speed 0.1–3.0, stop sync, leader leave.
- [ ] Spam remote UpdateAnimation/RequestSync dari console — server tidak banjir LoadAnimation.
- [ ] Favorites: toggle 20×, rejoin, cek persist; simulasi DataStore failure (Studio API off) → toggle ditolak, data lama utuh setelah rejoin.
- [ ] TipJar: donasi kecil/besar, donasi cepat setelah join (sebelum data load) → nilai Donated/Raised benar setelah load.
- [ ] Clone avatar, self-clone ditolak, spam clone (cooldown 3s).
- [ ] Mobile: tap vs drag vs hold; skala UI.
- [ ] 2+ player local server; MicroProfiler + Developer Console Memory; Instance & AnimationTrack count stabil setelah 10–20 menit.
- [ ] BindToClose: shutdown server saat ada data dirty → data tersimpan.

## I. PERBANDINGAN SEBELUM / SESUDAH

**SEBELUM:** 8 handler remote server (2 tanpa rate limit), 5 loop permanen + 4 Heartbeat client
(2 di antaranya dead-work tiap frame), preload asset di server, 1 HTTP call per buka panel,
6 tabel per-UserId tanpa cleanup lengkap, 4 bug data-loss/logic (C1–C4), banyak print debug,
error path bocor ke client.

**SESUDAH:** semua remote ber-rate-limit dan tervalidasi, error pakai kode tanpa prefix path,
lock selalu dilepas (pcall-guarded), cleanup PlayerRemoving lengkap di semua sistem,
follower cache TTL, playtime autosave, favorit fail-safe (read-only saat load gagal),
TipJar merge delta + key queue unik, client cooldown like, Heartbeat client di-throttle,
dead code & debug print hilang. Angka FPS/memori tidak kuklaim — perlu diukur runtime.

## J. KEJUJURAN

**Terbukti dari source:** C1, C2, C4, H1, H3–H5, H7–H9, M1–M13.
**Plausible (belum terverifikasi runtime):** C3 (tergantung representasi `tostring(DataStore)` —
fix-nya murah dan aman apa pun kenyataannya), efek visual koreksi drift heartbeat.
**Asumsi:** `OpenTipJar`/`BackToACM` adalah BindableEvent; GUI `AnimationsUI` punya struktur
child sesuai `WaitForChild` di script; FastBar memakai `_G.AnimationsUI` dan `_G.ACM_API`.
**Belum bisa diverifikasi tanpa runtime/asset:** perilaku roproxy, limit 64 AnimationTrack dalam
sesi panjang, TipJar VFX (butuh tool "Tip Jar" di karakter), TipJar UI client (tidak dikirim).
Sistem **belum** bisa dinyatakan 100% bebas bug tanpa runtime test — jalankan checklist H.
