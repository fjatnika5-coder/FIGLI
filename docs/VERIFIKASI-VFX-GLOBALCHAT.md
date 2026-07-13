# Verifikasi Penghapusan: VFXSplashHandler & GlobalChatRelay

Pemeriksaan rantai penuh berdasarkan source yang dikirim. Kesimpulan: **keduanya HASIL A — aman dihapus langsung, tanpa perubahan server lain maupun client.** Fitur cross-player VFX dan global chat tetap utuh.

---

## 1. VFX SPLASH

### Status
**Aman dihapus langsung.** FishingSystem server utama sudah memiliki handler lengkap yang tervalidasi. Tidak ada perubahan client. Tidak ada perubahan server lain.

### Rantai lengkap (bukti dari source)

**Pengirim — LocalScript `StarterPlayerScripts.FishingSystem`:**
- Satu-satunya pemanggil client: fungsi `onLandedInWater()` —
  `vfxSplashEvent:FireServer(currentRod, gameState.sinker.Position)`
- Hanya dipanggil sekali per cast (guard `gameState.hasLanded` + `stopLandingWatchers()`), hanya bila `RODS_WITH_SPLASH_SET[currentRod]`.
- Data yang dikirim: `rodName: string`, `splashPosition: Vector3`.
- Remote: `ReplicatedStorage.FishingSystem.VFXSplashEvent` (RemoteEvent).

**Handler server — Script FishingSystem server utama (`vfxSplashEvent.OnServerEvent`):**
Validasi yang SUDAH ada di handler ini:
1. Type check: `typeof(rodName) ~= "string"` → tolak; `isFiniteVector3(splashPosition)` (anti NaN/inf) → tolak.
2. Rod sedang dipakai: `character:FindFirstChild(rodName)` harus ada dan `:IsA("Tool")` — Tool hanya bisa masuk character dari grant server, jadi rod yang tidak dimiliki otomatis tertolak.
3. Rate limit: `canFireVFX(player, "VFXSplash")` — debounce 0.15 s per event + maksimum 8 event/detik per player (`VFX_MAX_PER_SECOND`), counter di-reset loop Heartbeat, cooldown di-prune tiap 30 s, dibersihkan saat PlayerRemoving.
4. Posisi: jarak HRP → splashPosition maksimum 200 stud (`VFX_SPLASH_MAX_DISTANCE`).
5. Broadcast: `for _, targetPlayer in ipairs(Players:GetPlayers()) do vfxSplashEvent:FireClient(targetPlayer, player, rodName, splashPosition) end` — **termasuk caster** (komentar source: "Kirim juga ke caster agar VFX miliknya sendiri terlihat").

**Penerima — LocalScript `FishingSystem` yang sama (`vfxSplashEvent.OnClientEvent`):**
- Caster **tidak** membuat splash lokal saat FireServer; efek miliknya datang dari echo server. Satu event = satu pembuatan efek per client → **tidak mungkin dobel** setelah handler tinggal satu.
- `spawnSplashVFXAtPosition` punya pertahanan sendiri: `canSpawnVFX` (cooldown 0.15 s per caster, max 2 aktif per caster, max 10 total), `RODS_WITH_SPLASH_SET[rodName]` harus true, template `Assets.VfxSplash[rodName]` harus ada.
- Cleanup: `Debris:AddItem(vfxClone, cleanupTime)` + bookkeeping `activeVFXPerPlayer`/`totalActiveVFX` + `cleanupPlayerVFX` saat PlayerRemoving. Tidak ada instance tersisa.
- Listener terpasang sekali (LocalScript di StarterPlayerScripts, tidak ResetOnSpawn) → respawn tidak menambah listener.

**Kenapa VFXSplashHandler berbahaya:**
- Handler KEDUA pada remote yang sama, hanya cek type — tanpa rod check, tanpa jarak, tanpa rate limit → client bisa spam `FireServer` dan server mem-broadcast ke semua player tiap kali (network flood).
- Saat keduanya aktif, tiap splash sah dibroadcast 2× (visual dobel hanya tertahan kebetulan oleh cooldown 0.15 s di client).
- Argumen ke-4 `sinkerCFrame` yang ia teruskan tidak pernah dibaca listener client → dead parameter.

**Setelah dihapus, remote tetap ada:** FishingSystem server utama membuatnya via `ensureRemote(FishingSystem, "VFXSplashEvent")`.

### Alur sebelum vs sesudah

Sebelum:
```
Client A FireServer ─┬→ Handler FishingSystem (valid) → FireClient semua  ┐
                     └→ Handler VFXSplashHandler (tanpa validasi) → FireClient semua ┘ = 2 event/client
```
Sesudah:
```
Client A FireServer → Handler FishingSystem (valid) → FireClient semua (termasuk A)
→ tiap client spawn efek 1× → Debris cleanup
```

### Residual yang dicatat (jujur, tidak diubah)
- Broadcast ke SEMUA player, bukan radius. Client penerima yang jauh tetap membuat efek (dibatasi max 10 total + Debris). Optimasi radius bisa ditambahkan nanti; bukan syarat fitur.
- Exploiter yang meng-equip Tool NON-rod (mis. tool ikan) lalu mengirim nama tool itu akan lolos validasi "tool equipped" → broadcast terjadi tetapi **nol efek visual** di semua penerima (`RODS_WITH_SPLASH_SET` dan lookup template gagal), dan tetap terkunci rate limit 8/detik. Rod palsu yang TIDAK di-equip/dimiliki tetap tertolak penuh. Dampak: setara noise splash sah, bukan flood.

### File
- Dihapus: `ServerScriptService/VFXSplashHandler`.
- Diganti: tidak ada.
- Tidak disentuh: FishingSystem server utama, LocalScript FishingSystem, semua client lain.

---

## 2. GLOBAL CHAT (GlobalFishCatch)

### Status
**Aman dihapus langsung.** GlobalFishRelay + SendChatMessage adalah jalur canonical yang sudah aktif. Tidak ada perubahan client.

### Rantai lengkap (bukti dari source)

**Publisher (satu-satunya):** Script FishingSystem server utama, di dalam `fishGiverEvent.OnServerEvent`, blok `if fish.rarity == "Unknown"`:
1. Tampilan server sendiri: `SendChatMessage:FireAllClients("General", player.Name, fish.name, fish.weight, fish.rarity)`.
2. Lintas server: `MessagingService:PublishAsync("GlobalFishCatch", {ServerId, Sender, FishName, Weight, Rarity})`.

Rarity ditentukan server (`serverSelectFish` / event override) — client tidak bisa memalsukan; hanya "Unknown" yang dipublish. Publisher tunggal, tidak ada publisher ganda.

**Subscriber:**
- `GlobalFishRelay` (dipertahankan): validasi payload (`Sender` string ≤50, `FishName` string ≤100, `Rarity == "Unknown"` wajib, `Weight` angka finite positif), **filter ServerId sendiri** (`data.ServerId == SERVER_ID and not IsStudio → return`), lalu `SendChatMessage:FireAllClients("Global", ...)`. Unsubscribe saat BindToClose.
- `GlobalChatRelay` (dihapus): subscriber KEDUA topic yang sama. Tanpa filter ServerId (pesan sendiri tampil dobel), tanpa filter rarity, tanpa validasi tipe, dan `FishingSystem:WaitForChild("ReceiveChatNotification")` **tanpa timeout** — remote `ReceiveChatNotification` tidak dibuat oleh script mana pun yang dikirim, jadi di setup sekarang script ini kemungkinan besar menggantung selamanya (infinite yield) alias sudah mati; kalau remotenya ada manual di Explorer, justru menghasilkan pesan duplikat.

**Client listener:** jalur aktif adalah `SendChatMessage` — dipakai juga oleh AdminLuckSystem dan BottleQuestServer untuk broadcast chat, dan pesan Unknown lokal sudah lewat remote ini. Artinya chat UI client pasti mendengarkan `SendChatMessage` (kalau tidak, pesan lokal pun tidak pernah tampil). `ReceiveChatNotification` tidak direferensikan oleh satu pun LocalScript yang dikirim.

### Alur sesudah
```
Catch Unknown (server A, tervalidasi server)
 ├→ SendChatMessage "General" → semua client server A (1×)
 └→ PublishAsync GlobalFishCatch
      → server B..N: GlobalFishRelay (validasi + filter ServerId)
          → SendChatMessage "Global" → semua client server itu (1×)
      → server A: difilter ServerId → tidak dobel
```

### Residual yang dicatat
- Di Studio (JobId kosong) GlobalFishRelay sengaja TIDAK memfilter pesan sendiri → di Studio bisa tampil 2× (lokal + echo). Perilaku bawaan script-mu, hanya Studio, dibiarkan.

### File
- Dihapus: `ServerScriptService/GlobalChatRelay`.
- Diganti: tidak ada.
- Tidak disentuh: GlobalFishRelay, FishingSystem server utama, client chat.
- Kalau remote `FishingSystem.ReceiveChatNotification` ada manual di Explorer dan tidak dipakai script lain: boleh dihapus manual (opsional).

---

## 3. Test checklist khusus

VFX:
- [ ] A cast rod ber-VFX → A melihat efek (via echo server) tepat 1×.
- [ ] B di dekat A melihat efek yang sama 1×.
- [ ] Spam FireServer (exploit-sim Studio) → maksimum 8/detik, sisanya drop; tiap caster maksimum 2 efek aktif.
- [ ] Nama rod yang tidak di-equip → tidak ada broadcast.
- [ ] Posisi >200 stud dari HRP → tidak ada broadcast.
- [ ] Player tanpa tool equipped → tidak ada broadcast.
- [ ] Respawn ×5 → tidak ada listener/efek dobel.
- [ ] Efek hilang sendiri (Debris) dan `totalActiveVFX` kembali turun.

Global chat:
- [ ] Satu catch Unknown → satu pesan di server sendiri.
- [ ] Server lain menerima satu pesan "Global".
- [ ] Server asal tidak menerima duplikat dari relay (produksi).
- [ ] Rarity selain Unknown → tidak ada pesan global.
- [ ] Publish payload invalid (uji manual PublishAsync dari command bar) → diabaikan relay.
- [ ] Studio tidak ada infinite yield di Output setelah GlobalChatRelay dihapus.
- [ ] Client hanya punya satu listener chat aktif (SendChatMessage).
