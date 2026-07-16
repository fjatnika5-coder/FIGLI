# AUDIT PERFORMA — Client 35–60 ms saat banyak pemain mancing

Cakupan: seluruh source yang dikirim. Fokus: beban client per-frame + spike saat splash/flash/fish caught dengan banyak pemancing.

---

## A. DIAGNOSIS

### Penyebab utama (terbukti dari source)

**1. Fan-out broadcast VFX splash: O(pemancing × semua player), tanpa radius.**
Server (`vfxSplashEvent.OnServerEvent`) `FireClient` ke SEMUA player untuk setiap splash. Setiap client — termasuk yang berada di ujung map — kemudian menjalankan `spawnSplashVFXAtPosition`:
- `vfxTemplate:Clone()` — template rod premium bisa berisi puluhan–ratusan descendant (emitter, beam, sound, mesh),
- `GetDescendants()` **3 kali** per splash: pass beam-attach, pass emitter/sound, dan `calculateVFXCleanupTime`,
- lalu Roblox mereplikasi + merender clone tersebut.

Dengan 10 pemancing rod VFX aktif bersamaan: setiap client melakukan sampai 10 clone berat + 30 pass GetDescendants dalam window pendek, ditambah render partikelnya. Ini persis pola "spike saat splash/VFX muncul" dan naik linear dengan jumlah pemancing. **Ini kandidat terkuat Client 35–60 ms.**

**2. Fan-out cast replication: O(pemancing × semua player) network.**
Server meneruskan setiap cast ke SEMUA player; client memang membuang caster berjarak >60 stud (`CAST_DISTANCE_LIMIT`), tetapi paket tetap dikirim, diterima, dan handler tetap berjalan di semua client. 20 pemancing = 20×19 pesan per gelombang cast + relay cleanup yang sama. Payload kecil, tetapi jumlah event dan handler-run naik kuadratik terhadap pemain.

**3. Render/engine cost partikel bersamaan.**
Budget lama: 10 splash aktif total, 2 per caster, full quality untuk semua — termasuk milik pemain lain dan pada perangkat mobile. Overdraw partikel transparan adalah biaya GPU/engine, bukan script; source tidak membatasi kualitas berdasarkan perangkat maupun jarak.

### Penyebab tambahan

**4. Simulasi hook pemain lain**: per hook ada Heartbeat connection (posisi 12 Hz + cek pendaratan 12.5 Hz, tiap cek = 1–10 raycast; cache air 0.12 s meredam). Dibatasi 4 hook — bounded, bukan akar utama, tapi ikut menyumbang saat ramai. Kini mengikuti tier perangkat.

**5. "Flash"**: tidak ada implementasi screen-flash yang berjalan di semua client dalam source — `GUIManager:PlayRareEffect` ada tetapi **tidak punya caller** di script yang dikirim; `CaughtFishVisual` sudah dihapus di patch sebelumnya. "Flash" yang dirasakan hampir pasti adalah kilatan terang template VFX splash (poin 1/3), yang memang diproses semua client. Notifikasi hasil ikan (NotificationManager/Small Notification) hanya berjalan pada pemilik tangkapan — bukan sumber lag lintas pemain.

### Klasifikasi bottleneck
- **Network + script CPU**: fan-out tanpa radius (1, 2) — diperbaiki.
- **Script CPU spike**: clone + 3× GetDescendants per splash (1) — dipangkas 1 pass via cache, dibatasi radius/budget/tier.
- **GPU/engine**: jumlah + kualitas partikel bersamaan (3) — budget & skala per tier.
- **Bukan penyebab**: DataStore, inventory, sell, quest — tidak berjalan di jalur per-frame client.

### Yang butuh MicroProfiler/runtime test
- Proporsi pasti script CPU vs GPU pada 35–60 ms.
- Apakah spike pertama kali splash muncul berasal dari decode asset (texture/mesh template VFX) — kalau ya, tambahkan preload kecil (lihat bagian PRELOAD).
- Biaya render Beam garis pancing banyak pemain.

---

## B. PETA ALUR SATU CAST

```
Input (klik/tap) → PowerBar → performCast (client)
 → CastReplication:FireServer(rodPos, vel, rodName, power)
    → server: validasi (type, finite, kecepatan, jarak rod, rod owned+equipped,
      cooldown 0.4s, session) → buat session
    → [SESUDAH] FireClient hanya ke player dalam CastBroadcastRadius (80)
       → client lain (≤60 stud): hook simulasi (EasyPool) + beam, sim 8–12 Hz per tier
 → client caster: hook fisik + beam + waterConn Heartbeat (cek air 10 Hz, raycast cached)
 → landing air → VFXSplashEvent:FireServer(rodName, pos)
    → server: validasi (type, finite, tool equipped, rate 8/s, jarak ≤200)
    → [SESUDAH] FireClient ke caster + player dalam VfxBroadcastRadius (150)
       → client: [SESUDAH] gate jarak tier → budget (total/per-caster/cooldown tier)
         → clone template → emit (skala tier utk caster lain) → Debris cleanup (waktu di-cache per rod)
 → bubble splash lokal (3×, hanya caster) → minigame → sukses
 → FishGiver:FireServer → server roll ikan → data + tool → FishCaughtResult:FireClient (HANYA caster)
    → notifikasi hasil (personal) ; Unknown → SendChatMessage all (data ringan) + MessagingService
 → cleanup: CleanupCast → [SESUDAH] relay radius-culled; client lain punya safety timeout 15 s
```

## C. DAFTAR BOTTLENECK

**CRITICAL**
- FishingSystem server `vfxSplashEvent` handler — broadcast semua player → radius 150 + caster. (Fan-out O(P²) → O(P × tetangga).)
- FishingSystem client `spawnSplashVFXAtPosition` — clone berat + 3× GetDescendants per splash, budget flat → cache cleanup-time per rod (−1 pass), distance gate, budget & skala per tier.

**HIGH**
- FishingSystem server `castReplicationEvent` — broadcast semua player padahal client buang >60 stud → radius 80.
- FishingSystem server `cleanupCastEvent` — sama → radius 150 (safety timeout client tetap ada).
- Kualitas VFX seragam untuk mobile & PC → tier HIGH/MEDIUM/LOW (SavedQualityLevel + jenis perangkat, read-only).

**MEDIUM**
- Simulasi hook pemain lain: interval & jumlah maksimum kini per tier (LOW: 2 hook, 8 Hz).
- `NearbyEmitMultiplier`: partikel efek pemain lain diskalakan (HIGH 1.0 / MEDIUM 0.6 / LOW 0.35); efek milik sendiri selalu full.

**LOW (dicatat, tidak diubah)**
- Bubble splash lokal clone 3×/catch — kecil, hanya caster, Debris 1 s.
- `waterConn` raycast 10 Hz saat hook sendiri terbang — hanya selama fase jatuh, cache aktif.
- Beam garis pancing per pemancing — engine render, bounded oleh MaxOtherHooks.
- `publishFishCatchEvent` remote nganggur — tanpa biaya.
- Hook part `CanQuery/CanTouch` masih default true — biaya broadphase kecil (raycast sudah meng-exclude via ignore list); opsional dimatikan di template CastingSystem nanti.

## D. SOLUSI ARSITEKTUR

- **Personal**: FishCaughtResult, notifikasi hasil, sound minigame — sudah personal, tidak diubah.
- **Nearby (radius, server-authoritative)**: VFX splash (150), cast replication (80), cleanup relay (150). Posisi divalidasi server sebelum broadcast (jarak ≤200 dari HRP caster) — client tidak dipercaya.
- **Global data-only**: SendChatMessage Unknown catch + MessagingService — teks ringan, tetap ke semua (tidak memicu VFX berat).
- **LOD/tier client**: HIGH/MEDIUM/LOW — radius terima, budget efek, skala emit efek orang lain, jumlah & frekuensi sim hook lain.
- **Cache**: waktu cleanup VFX per rod (hapus 1 GetDescendants penuh per splash); cache air 2-stud/0.12 s sudah ada; texture ikan sudah di-cache.
- **Pooling**: hook sudah EasyPool. Pooling clone VFX TIDAK dipakai — template punya state emit berbasis attribute + Debris lifecycle; reset state penuh lebih berisiko daripada manfaatnya pada volume yang kini sudah dibatasi radius+budget.
- **Fitur dipertahankan**: pemain dekat tetap melihat splash pemain lain full-radius 150 (HIGH); tidak ada efek yang dihapus.

## E. FILE FINAL (full source di repo)

| Repo path | Lokasi Explorer |
|---|---|
| `ReplicatedStorage/FishingSystem/FishingPerfConfig.lua` | **BARU** — ModuleScript `ReplicatedStorage.FishingSystem.FishingPerfConfig` |
| `ServerScriptService/FishingSystemServer.server.lua` | **GANTI** isi Script fishing server utama (yang berisi FishGiver/CastReplication/SellFish) |
| `StarterPlayer/StarterPlayerScripts/FishingSystem.client.lua` | **GANTI** isi LocalScript `StarterPlayerScripts.FishingSystem` |

## F. DAFTAR PERUBAHAN

DIGANTI: FishingSystem server utama (3 loop broadcast → radius; +require PerfConfig; sisanya identik), FishingSystem client (PERF-2..6; gameplay, minigame, cast, cleanup identik).
DITAMBAH: FishingPerfConfig.
DIHAPUS: tidak ada (VFXSplashHandler & GlobalChatRelay sudah dihapus di audit sebelumnya — prasyarat perbaikan ini).
TETAP: semua module (CastingSystem, MinigameSystem, PowerBar, GUIManager, SoundManager — sudah reusable/pooled), semua sistem data/sell/quest/bottle/shop.

## G. CONFIG PERFORMA (semua di FishingPerfConfig)

Server: `VfxBroadcastRadius=150`, `CastBroadcastRadius=80`, `CleanupBroadcastRadius=150`.
Client per tier: `NearbyEffectRadius`, `MaxTotalEffects`, `MaxEffectsPerPlayer`, `VfxCooldown`, `NearbyEmitMultiplier`, `MaxOtherHooks`, `OtherHookPhysicsInterval`, `OtherHookLandCheckInterval`. `ForceQuality` untuk paksa tier saat debugging. Rate limit remote server tetap di script server (nilai lama, tidak berubah).

## H. TEST PLAN

1 pemain: cast 20×, catch 20×, spam cast cepat, respawn ×5 — Output bersih, VFX sendiri selalu full.
5 pemain (satu titik): cast bersamaan, catch bersamaan — tiap client hanya menerima cast/splash tetangga ≤ radius; MicroProfiler bandingkan frame time vs versi lama.
10 pemain: (a) satu lokasi — cek `totalActiveVFX` ≤ budget tier; (b) tersebar >150 stud — client harus TIDAK menerima splash/cast pemain jauh (cek Network Receive di Developer Console turun drastis vs lama).
20 pemain: stress cast+catch bersamaan, banyak rod VFX; rare catch bersamaan (pesan global tetap 1×/catch).
Monitor: Client/Server frame time, FPS, GPU, Memory, Instance count, Network recv/send (F9 → Network), ParticleEmitter count, AnimationTrack count, MicroProfiler tag spike saat splash.
Mobile: uji tier auto (harus MEDIUM/LOW), lalu `ForceQuality="HIGH"` untuk pembanding.

## I. SEBELUM vs SESUDAH

| | Sebelum | Sesudah |
|---|---|---|
| Splash broadcast | semua player | caster + radius 150 (server) + gate radius tier (client) |
| Cast broadcast | semua player (client buang >60) | radius 80 |
| Cleanup relay | semua player | radius 150 + safety timeout client |
| GetDescendants per splash | 3 pass | 2 pass (cleanup-time di-cache per rod) |
| Kualitas efek orang lain | full untuk semua perangkat | skala tier (1.0/0.6/0.35) |
| Budget efek | 10 total / 2 per caster (flat) | per tier: 10/2, 6/1, 3/1 |
| Sim hook lain | 4 hook, 12 Hz flat | per tier: 4/12Hz, 3/10Hz, 2/8Hz |
| Efek milik sendiri | full | full (tidak berubah) |
| Angka performa | — | tidak dijanjikan; ukur dengan test plan H |

## J. KEJUJURAN

- **Terbukti dari source**: fan-out tanpa radius (3 titik), clone+3×GetDescendants per splash, budget flat tanpa tier, sim hook konstanta flat.
- **Potensial (belum terbukti)**: spike pertama karena asset decode template VFX; biaya render beam banyak pemain; overdraw partikel spesifik template (isi template tidak dikirim — rate/lifetime/size partikel di dalam template TIDAK bisa kuaudit; kalau setelah patch masih berat saat 1–2 splash dekat, masalahnya di isi template → turunkan Rate/Lifetime/LightEmission di asset, atau turunkan `NearbyEmitMultiplier`).
- **Asumsi**: "flash" = kilatan template VFX splash, karena tidak ada screen-flash ber-caller di source; `PlayRareEffect` tanpa caller.
- **Butuh runtime test**: semua angka radius/budget adalah nilai awal yang masuk akal, bukan hasil profiling — tuning via FishingPerfConfig setelah MicroProfiler.
- **Tidak dikirim/di luar audit**: isi asset template VfxSplash, chat UI listener SendChatMessage, GUI.
- Preload: tidak ditambahkan — belum ada bukti spike-nya dari loading; kalau MicroProfiler menunjukkan spike hanya pada splash PERTAMA per rod, tambahkan `ContentProvider:PreloadAsync` untuk 3–5 template VfxSplash rod terpopuler saja (bukan seluruh game).

---

# UPDATE — VFX LOD BERTINGKAT (revisi hard cutoff 150)

Menggantikan distance-gate keras dengan LOD. Bagian G lama (NearbyEffectRadius/MaxEffectsPerPlayer/NearbyEmitMultiplier) digantikan key baru di bawah.

## Perilaku baru

Server: `VfxBroadcastRadius` 150 → **350** (efek pemain jauh kini dikirim; penerimanya merender versi murah). Kode server tidak berubah — hanya nilai config.

Client per event splash → pilih LOD dari jarak:

| LOD | Jarak (HIGH) | Komponen | Emit |
|---|---|---|---|
| LOCAL | milik sendiri | semua | 1.0 |
| NEAR | ≤80 | semua (Sound/Light/Beam/Trail hidup) | ×NearEmitMultiplier (1.0) |
| MID | ≤180 | tanpa Sound + Light | ×MidEmitMultiplier (0.45) |
| FAR | ≤350 | tanpa Sound + Light + Beam + Trail; cleanup ≤3 s | ×FarEmitMultiplier (0.15) |
| >FarRadius | — | skip (counter `skippedRange`) | — |

Template VFX SAMA untuk semua LOD — komponen mahal di-Destroy pada clone, EmitCount/Rate diskalakan. MEDIUM: 60/140/250, 0.6/0.3/0.1. LOW: 50/100/160, 0.35/0.2/0.08.

## Jaminan yang diminta

- **Satu cast = satu splash**: client fire 1×/landing (guard `hasLanded`), server debounce 0.15 s + 8/s, dan client `tryReserveVFXBudget` menolak event kedua per caster dalam `VfxCooldown` (counter `duplicateBlocked` membuktikan setiap duplikat yang ditolak). Per caster maksimal 1 efek aktif (yang baru menggantikan miliknya).
- **Maks SATU GetDescendants per clone**: satu pass mengumpulkan emitters/sounds/beams/trails/lights + positioning Folder sekaligus; pass beam-attach & emit bekerja dari list; cleanup-time dihitung dari list itu dan di-cache per rod (`vfxCleanupTimeCache`) — clone berikutnya rod yang sama memakai cache.
- **Prioritas budget**: saat `MaxTotalEffects` penuh — efek LocalPlayer SELALU masuk (menggusur efek non-lokal terjauh); efek lain masuk hanya bila lebih dekat daripada efek non-lokal terjauh (yang terjauh digusur, counter `evictedForPriority`); selain itu ditolak (`skippedBudget`). Efek lokal tidak pernah digusur oleh efek orang lain.
- **Pembuktian runtime**: `_G.GetFishingVFXStats()` dari command bar client → `{spawnedTotal, spawnedLocal/Near/Mid/Far, skippedRange, skippedBudget, duplicateBlocked, evictedForPriority, activeNow, quality}`. MicroProfiler: cari label **"FishingSplashVFX"** (membungkus clone + traversal + apply LOD) — bandingkan durasinya antar LOD dan vs versi lama.
- **Pooling**: TIDAK dibuat. Keputusan menunggu bukti: kalau setelah patch label "FishingSplashVFX" masih menunjukkan spike dominan pada Clone/Parent (bukan render partikel), baru pertimbangkan pooling.

## Test tambahan

- 2 client Studio, jarak 200 stud: pemancing A splash → client B harus render FAR (tanpa sound/beam, partikel sedikit), `spawnedFar` naik.
- Jarak 30 stud: `spawnedNear` naik, sound terdengar.
- 12 pemancing bersamaan (HIGH, budget 10): `evictedForPriority`/`skippedBudget` naik, yang tampil = milik sendiri + 9 terdekat.
- Spam cast 1 pemain: `duplicateBlocked` = 0 pada gameplay normal (bukti satu cast satu splash); naik hanya kalau ada event duplikat.
- MicroProfiler: durasi "FishingSplashVFX" FAR < NEAR; pass kedua rod sama lebih cepat (cache cleanup-time).

## Kejujuran tambahan

- Radius kirim naik 150→350 = lebih banyak penerima per splash; trade-off sengaja: penerima jauh kini memproses versi FAR yang murah (tanpa sound/light/beam/trail, emit ±15%). Kalau Network Receive jadi masalah di server 20+ pemain, turunkan `VfxBroadcastRadius` — client otomatis ikut.
- Efek skala emit pada template yang HANYA memakai `Enabled=true` (tanpa attribute EmitCount): hanya Rate yang turun; burst instan template semacam itu tidak terpengaruh — tergantung isi asset (tidak dikirim).
- Belum runtime-test; Luau syntax belum dieksekusi — jalankan di Studio, cek Output bersih dulu.
