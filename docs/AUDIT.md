# AUDIT FINAL — Sistem Fishing FIGLI

Tanggal: 2026-07-13. Cakupan: seluruh script yang dikirim (server, client, module, EasyPool rbxm, AuraData, RodShopConfig, AdminRodManager, MoneyReward, PlayerHandler).

Prinsip perbaikan: patch tertarget pada akar masalah, bukan rebuild. Struktur, gameplay, UI, dan format data DataStore **tidak berubah** — tidak perlu migrasi data.

---

## A. RINGKASAN AUDIT

### CRITICAL

**C1 — Handler ClaimReward dobel (dupe race quest reward)**
- Lokasi: `FishData` (ModuleScript) + `QuestBoardServer V1` (Script).
- Masalah: dua server listener pada RemoteEvent `QuestRemotes.ClaimReward`. Satu klik claim mengeksekusi dua handler paralel; keduanya membaca `RewardClaimed=false` sebelum salah satu menulis `true`.
- Dampak: logic claim jalan dua kali, race state, log ganda. Rod tidak terduplikasi hanya karena `AddRod` kebetulan dedup by-name — proteksi tidak sengaja.
- Perbaikan: handler di FishData **dihapus**. QuestBoardServer V1 (yang punya debounce + ClaimResult feedback) jadi satu-satunya otoritas claim. FishData tetap memiliki remotes + helper data quest.

**C2 — VFXSplashHandler duplikat & tanpa validasi (exploit network flood)**
- Lokasi: `ServerScriptService/VFXSplashHandler` + `FishingSystem` server utama.
- Masalah: dua `OnServerEvent` pada `VFXSplashEvent`. Versi VFXSplashHandler tidak punya validasi rod equip, jarak, maupun rate limit — client bisa spam `FireServer` dan server broadcast ke semua player tiap kali.
- Dampak: exploit DoS ringan (banjir remote ke semua client), setiap splash sah dikirim 2×.
- Perbaikan: **hapus file VFXSplashHandler**. Handler tervalidasi di FishingSystem server (rod equip check, jarak ≤200, debounce, max/detik) sudah lengkap.

**C3 — GlobalChatRelay duplikat + infinite yield**
- Lokasi: `ServerScriptService/GlobalChatRelay` vs `GlobalFishRelay`.
- Masalah: dua subscriber topic MessagingService `GlobalFishCatch`. GlobalChatRelay `WaitForChild("ReceiveChatNotification")` tanpa timeout — kalau remote itu tidak ada, thread yield selamanya; kalau ada, pesan global tampil dobel (SendChatMessage + ReceiveChatNotification) dan tidak memfilter ServerId sendiri (pesan lokal dobel).
- Perbaikan: **hapus GlobalChatRelay**. GlobalFishRelay (validasi tipe, filter ServerId, unsubscribe on close) jadi satu-satunya relay.

**C4 — Fish transfer menghasilkan uniqueId baru (tool orphan)**
- Lokasi: `FishData:AddFish` ← `DataManager:AddExistingFish` ← `FishTransferServer`.
- Masalah: `AddFish` selalu generate GUID baru dan mengabaikan `uniqueId` bawaan. Penerima transfer mendapat entry data dengan id baru, tetapi tool fisik dibuat dengan id lama → tool tidak match data: tidak bisa dijual/di-favorite lewat tool, sell-by-tool gagal. Rollback sender sama rusaknya.
- Perbaikan: `AddFish` sekarang mempertahankan `uniqueId`, `timestamp`, `isFavorited` bila disuplai, dan **idempotent** (re-add id yang sudah ada = no-op sukses → rollback ganda tidak bisa dupe). Ikan hasil transfer (id disuplai) tidak menaikkan `TotalFishCaught`/`UnknownFishCaught` (dulu transfer bolak-balik bisa memompa statistik & leaderboard).

**C5 — Auto-cleanup menghapus ikan favorit (data loss)**
- Lokasi: `FishData.cleanupOldFish`.
- Masalah: pemangkasan >2500 ikan sort by timestamp dan buang yang tertua **tanpa memedulikan `isFavorited`** — ikan favorit/Unknown yang lama tertangkap ikut terhapus permanen.
- Perbaikan: favorit selalu dipertahankan; hanya non-favorit tertua yang dipangkas sampai target.

**C6 — RodAuraRemote tanpa ownership check (aura gratis)**
- Lokasi: `ServerScriptService/RodAuraRemote`.
- Masalah: validasi kepemilikan berupa komentar TODO. Client mana pun bisa `FireServer("Equip", "Aura_ChaosInsanity")` dan mendapat aura visual tanpa membeli.
- Perbaikan: equip hanya bila aura terdaftar di `AuraData.Auras` **dan** dimiliki (`PlayerData.Inventory.Auras[nama]` — folder yang dibuat PlayerHandler — atau `EquippedAura` value).

### HIGH

**H1 — Split-brain kepemilikan rod: FishData vs RodInventoryServer**
- Masalah: dua penyimpanan ownership. Admin "remove rod" hanya menyentuh RodInventory (blacklist), sementara `FishData.OwnedRods` tetap berisi rod itu → `restoreOwnedRods` di FishingSystem server mengembalikan tool tiap respawn; `HasRod` tetap true → rod tetap bisa dipakai mancing. Admin removal efektifnya tidak jalan.
- Perbaikan (terpusat di FishData supaya semua consumer ikut benar tanpa diubah):
  - `HasRod`/`GetOwnedRods` memfilter blacklist via `_G.RodInventory_IsBlacklisted` (nil-safe).
  - `AddRod` juga memanggil `_G.RodInventory_AddOwned` (sinkron dua store + auto-unblacklist → beli ulang/regrant setelah removal bekerja).
  - Fungsi baru `RemoveRod` (profile + blacklist + destroy tool).
  - `AdminRodManager_Server` memakai `GameProfileService:AddRod/RemoveRod` sebagai jalur utama.
- Efek berantai yang ikut benar tanpa diedit: FishingSystem server (restore & hasRod via DataManager), InventoryServer (equip check), RodShopGuiServer (cek owned sebelum beli).

**H2 — AdminLuckSystem memproses command dua kali**
- Masalah: `player.Chatted` **dan** `TextChatService...ShouldDeliverCallback` dua-duanya memanggil `processCommand`. Player.Chatted sudah fire untuk pesan TextChatService → `!luck global` dieksekusi 2× (dua publish MessagingService, dua boost task). Bonus bug: `ShouldDeliverCallback` hanya boleh satu callback game-wide — script ini merampasnya.
- Perbaikan: blok ShouldDeliverCallback dihapus; hanya Chatted.

**H3 — ForceReload remote bisa dispam (DataStore churn)**
- Lokasi: `FishData` handler `ProfileRemotes.ForceReload`.
- Masalah: tanpa cooldown; setiap fire me-release profile aktif lalu `LoadProfileAsync` ulang → spam client = throttle DataStore, churn session lock, data race.
- Perbaikan: cooldown 10 detik/player + diabaikan bila profile masih aktif (reload hanya untuk kondisi stuck/failed, sesuai maksud fitur).

**H4 — Jalur uang paralel (JualIkanServer tulis leaderstats.Money langsung)**
- Masalah: tiga jembatan nilai (`PlayerData.Cash` ↔ `leaderstats.Money` ↔ `leaderstats.Coins`) dengan guard flag berbeda; JualIkan menulis Money mentah dan mengandalkan bridge untuk sampai ke Cash (data asli DataStore2). Bridge putus/telat = uang hilang/desync.
- Perbaikan: JualIkan membayar via `FishData:AddCoins` (CurrencyAdapter → PlayerData.Cash). Semua sell path (JualIkan, InventoryServer SellAll, FishingSystem SellFish/AutoSell, RodShop refund) kini satu jalur adapter.

**H5 — JualIkan "Sell All" re-entrant**
- Masalah: debounce lama direset dengan `task.defer` — begitu Sell All yield, lock sudah lepas → request kedua jalan paralel di snapshot yang sama. Tidak dupe uang (RemoveFish atomik), tapi kerja dobel + dua reply.
- Perbaikan: lock dipegang penuh sampai selesai (pcall-guarded supaya lock tidak macet saat error), yield tiap 25 ikan.

### MEDIUM (dicatat, sebagian besar TIDAK diubah — risiko rendah / by design)

- **M1** `FishData:GetProfile` polling `task.wait(0.2)` per panggilan. Saat profile aktif return instan (jalur panas aman); hanya boros saat profile gagal load. Dibiarkan — mengubah ke signal-based menyentuh semua caller.
- **M2** Recovery loop `ListenToRelease → task.delay(3) → ForceReloadProfile` bisa ping-pong bila session lock direbut server lain berulang. Kejadian nyata jarang; dibiarkan.
- **M3** Kolisi command chat: `!done` ada di QuestAdminCmd V1 (by UserId) dan QuestV2 AdminCmd (by Name) — kalau admin sama terdaftar di keduanya, satu chat menyelesaikan dua quest board. Dibiarkan (behavioral; konfirmasi dulu kalau mau dipisah jadi `!done2`).
- **M4** Tiga jalur sell paralel (JualIkan NPC, InventoryServer SellAll, FishingSystem SellFish remote). Aman dari dupe karena semuanya `RemoveFish` dulu (atomik) baru bayar; dibiarkan karena tiga UI berbeda memakainya.
- **M5** `RodLuckMultiplier` menumpuk connection entry per respawn di tabel per-player (connection lama mati bersama karakter, tabel dibersihkan saat leave). Bocor kecil ber-batas; dibiarkan.
- **M6** Leaderboard `savePlayerNow` bisa block 5 detik/pemain saat profile hilang (BindToClose sekuensial). Ber-batas; dibiarkan.
- **M7** `AuraData` di-require server & client; `WaitForChild("AurasFolder")` di require-time — kalau folder tidak ada, semua requiring script hang. Pastikan `ReplicatedStorage.AurasFolder` ada.
- **M8** `FrozenkRod` & `Princess Parasol` punya dua jalur perolehan (gamepass shop + reward BottleQuest). By design? Dibiarkan.
- **M9** InventoryServer `onGetData` tidak mengirim `RodTextures/SkinTextures/OwnedSkins/EquippedRodSkin` yang dibaca client — client nil-safe, fitur skin tidak aktif. Dibiarkan (fitur belum ada server-side).
- **M10** Hotbar client memakai `Inventory_SaveHotbar/LoadHotbar` yang tidak ada server-side → hotbar tidak persist antar-join. Client sudah nil-safe. Dibiarkan sesuai konfirmasi "adanya ini".

### LOW

- Dead code `local ClaimRewardConnection if ClaimRewardConnection then...` di QuestBoardServer V1 (selalu nil) — tidak berbahaya, file tidak disentuh.
- `publishFishCatchEvent` dibuat di FishingSystem server tapi tidak pernah dipakai (client sudah tidak publish) — remote nganggur, aman.
- `GamepassEffectsHandler` seluruhnya stub "future update" — tidak dipanggil siapa pun; boleh dihapus manual kalau mau, tidak wajib.
- `DataManager:GetLevel` memanggil `FishData:GetLevel` yang **tidak ada** → error kalau dipanggil. Tidak ada caller di file yang dikirim; dibiarkan (kalau ada caller di tempat lain, kabari).
- Banyak print startup emoji — dikurangi hanya pada file yang memang diedit.

---

## B. DAFTAR PERUBAHAN

### Diubah (full script di repo, siap copy-paste)

| File | Lokasi Roblox | Fix |
|---|---|---|
| `ServerScriptService/Data/PetCore/FishData.lua` | ModuleScript `ServerScriptService.Data.PetCore.FishData` | C1, C4, C5, H1, H3 |
| `ServerScriptService/AdminLuckSystem.server.lua` | Script `ServerScriptService.AdminLuckSystem` | H2 |
| `ServerScriptService/RodAuraRemote.server.lua` | Script `ServerScriptService` (script pembuat RodAuraRemote) | C6 |
| `ServerScriptService/AdminRodManager_Server.server.lua` | Script `ServerScriptService.AdminRodManager_Server` | H1 |
| `ServerScriptService/JualIkanServer.server.lua` | Script `ServerScriptService.JualIkanServer` | H4, H5 |

### Dihapus (jangan dipasang lagi)

| File | Alasan |
|---|---|
| `ServerScriptService/VFXSplashHandler` | Duplikat handler `VFXSplashEvent` tanpa validasi (C2). Fungsinya 100% sudah dicover FishingSystem server. |
| `ServerScriptService/GlobalChatRelay` | Duplikat subscriber `GlobalFishCatch` + infinite yield + pesan dobel (C3). GlobalFishRelay menggantikan. |

### Tidak diubah (tetap pakai versi yang kamu kirim)

CurrencyAdapter, ProfileService, QuestBoardServer V1 & V2, QuestAdminCmd V1, QuestV2 AdminCmd, FishTransferServer, FishingSystem server utama, GlobalFishRelay, InventoryServer V2, RodShopEvents init, RodShopGuiServer, FishingLeaderboard, LegendaryEventServer, RodInventoryServer, RodLuckMultiplier, BottleQuestServer V5, MoneyReward, PlayerHandler, semua LocalScript client, semua ModuleScript (FishingConfig, BottleQuestConfig, AnimationController, CastingSystem, DataManager, NotificationManager, GUIManager, MinigameSystem, PowerBarSystem, SoundManager, GamepassEffectsHandler, AuraData, RodShopConfig), ObjectPoolingEngine.

Kompatibilitas API: tidak ada signature yang berubah; hanya penambahan `GameProfileService:RemoveRod` dan parameter opsional pada data `AddFish`. Semua caller lama tetap valid.

---

## C. STRUKTUR EXPLORER FINAL (delta saja)

```
ServerScriptService
├── Data/PetCore/FishData          ← GANTI (ModuleScript)
├── AdminLuckSystem                ← GANTI (Script)
├── AdminRodManager_Server         ← GANTI (Script)
├── JualIkanServer                 ← GANTI (Script)
├── <script RodAuraRemote>         ← GANTI (Script)
├── VFXSplashHandler               ← HAPUS
└── GlobalChatRelay                ← HAPUS
```

Remote yang wajib tetap ada (dibuat otomatis oleh script): `ProfileRemotes.{ProfileStatus,ForceReload}`, `QuestRemotes.{UpdateQuestUI,ClaimReward,ClaimResult}`, `QuestRemotesV2.*`, `FishingSystem.{FishGiver,CastReplication,CleanupCast,ShowNotification,SellFish,SendChatMessage,FishPopEvent,FishCaughtResult,VFXSplashEvent,ValidatedFishCaught}`, `FishingSystem.InventoryEvents.*`, `FishingSystem.RodShopEvents.*`, `FishingSystem.AdminRemotes.*`, `FishingSystem.BottleQuestRemotes.*`, `FishingSystem.EventRemotes.*`, `ReplicatedStorage.RodAuraRemote`, `ReplicatedStorage.JualIkanRemote`, `ReplicatedStorage.RodInventory.*`.

Nama object yang harus persis: `ReplicatedStorage.AurasFolder`, `ReplicatedStorage.AuraData`, `ServerScriptService.Data.DataModule.ProfileService`, `ServerScriptService.Fishing.CurrencyAdapter`, `ServerStorage.AllRods`, `FishingSystem.Assets.Fish`.

---

## D. PETUNJUK MIGRASI

1. **Backup**: publish versi saat ini ke place cadangan / simpan copy semua script lama.
2. Ganti isi 5 script sesuai tabel B (source lengkap ada di repo, path sama).
3. Hapus `VFXSplashHandler` dan `GlobalChatRelay` dari ServerScriptService.
4. Tidak ada perubahan Attribute, DataStore key, atau format data — data player lama langsung kompatibel.
5. Urutan uji: Studio solo → Studio 2-player (Local Server) → published server privat.
6. Rollback: kembalikan 5 script lama + pasang lagi 2 script yang dihapus (semuanya self-contained, tidak ada perubahan data yang mengunci).

---

## E. TEST CHECKLIST

Fungsional inti:
- [ ] Join → data load, leaderstats Money/Coins muncul, nilai konsisten dengan Cash.
- [ ] Mancing normal: cast → minigame → dapat ikan → notifikasi → data masuk inventory.
- [ ] Splash VFX muncul 1× (bukan 2×) di caster dan player lain.
- [ ] Unknown catch → pesan global muncul 1× di server sendiri dan 1× di server lain.
- [ ] Quest V1: !done admin → claim → dapat Aqua Rod **satu kali**; klik claim spam → hanya satu ClaimResult sukses.
- [ ] Transfer ikan A→B: B bisa jual/equip/favorite ikan hasil transfer (tool id match). Statistik TotalFishCaught B tidak naik.
- [ ] Transfer gagal (inventory penuh) → ikan kembali ke A dengan id sama, tidak dobel.
- [ ] Jual ikan (NPC JualIkan, Sell All inventory, SellFish remote) → Cash bertambah benar, Money/Coins ikut.
- [ ] Favorit ikan → tidak terjual Sell All, dan **tidak terhapus** ketika inventory >2500 ikan (uji dengan admin fill / turunkan threshold sementara).
- [ ] Admin `!rod` → remove rod dari player → rod hilang dari UI, tool hancur, **tidak balik setelah respawn/rejoin**.
- [ ] Admin add rod (atau beli ulang di shop) setelah pernah di-remove → rod kembali normal.
- [ ] Aura: equip aura yang dimiliki → jalan; FireServer aura yang tidak dimiliki (uji via script exploit-sim di Studio) → ditolak.
- [ ] `!luck global 2 1` → hanya SATU notifikasi boost per server, boost berakhir tepat waktu.
- [ ] Spam ForceReload dari client → maksimal satu reload per 10 detik, tidak ada saat profile aktif.

Lifecycle:
- [ ] Reset karakter / respawn ×5 → tidak ada GUI dobel, rod ter-restore, tidak ada error Output.
- [ ] Leave saat transfer pending / saat Sell All berjalan → tidak ada error, tidak ada dupe.
- [ ] 2 player: transfer bersamaan dua arah, sell bersamaan.
- [ ] Mobile: tombol CAST/TAP, inventory, shop.
- [ ] BindToClose (stop Studio server) → save jalan tanpa error.

Profiling:
- [ ] Developer Console → Server Memory sebelum/sesudah 10 menit mancing (Instance count stabil).
- [ ] MicroProfiler saat 4+ player casting bersamaan.

---

## F. BATAS KEJUJURAN

- **Terbukti dari code**: semua item CRITICAL/HIGH di atas terlihat langsung di source (dua listener pada remote yang sama, GUID selalu digenerate ulang, sort tanpa filter favorit, TODO ownership, dst.).
- **Belum diverifikasi runtime**: semua perbaikan belum dijalankan di Roblox Studio — sistem ini butuh asset (GUI, AllRods, AurasFolder, Fish templates) yang hanya ada di place kamu. Jalankan checklist E sebelum publish.
- **Asumsi**: struktur GUI sesuai referensi client; `ReplicatedStorage.AurasFolder` ada; pembelian aura mengisi `PlayerData.Inventory.Auras` (dari PlayerHandler/ShopModule — ShopModule tidak dikirim, jadi kalau pembelian aura menyimpan ownership di tempat lain, fungsi `ownsAura` di RodAuraRemote perlu disesuaikan; kabari struktur ShopModule kalau equip aura yang sah tertolak).
- **Tidak diaudit dalam**: internal DataStore2, DefaultData, RBXModule, ShopModule, ShopAssets (tidak dikirim).
