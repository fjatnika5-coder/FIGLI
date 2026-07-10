# Laporan Perbaikan Script (all_script.rbxm)

Total script diekstrak: **303**. Setelah pembersihan duplikat: **254**.
Semua file diuji parse (Luau syntax) sebelum dan sesudah perbaikan — 100% lolos.

## Memory Leak & Bug yang Diperbaiki

### 1. `LocalScript.client.lua` (ClientOptimizer)
- **Leak fatal**: setiap respawn karakter, `ShadowLOD:Start()` dan `NPCLodManager:Start()` dipanggil ulang → loop `while true` menumpuk terus (respawn 10x = 20 loop jalan bersamaan → lag makin parah). Sekarang loop hanya start sekali.
- **Leak memori**: cache `_disabled` menahan referensi part yang sudah di-Destroy selamanya. Diganti weak table (`__mode="k"`) sehingga part hancur otomatis lepas dari cache.

### 2. `MusicUI/PlayerHandler.client.lua`
- **Leak koneksi**: setiap drag slider volume membuat koneksi `mouse.Button1Up` baru yang tidak pernah di-disconnect → menumpuk tiap drag. Sekarang ikut di-disconnect.
- **Lag per-frame**: tiap lagu di playlist punya koneksi `Heartbeat` sendiri untuk update ukuran (N lagu × 60 fps). Diganti event `AbsoluteSize` changed (hanya jalan saat ukuran berubah).
- **Lag per-frame**: `updatePlaylistSongsSize` jalan tiap frame. Diganti event `ChildAdded/ChildRemoved/AbsoluteContentSize`.

### 3. `NametagRole.client.lua`
- **Bug**: klik pilih player memanggil `populatePlayers()` ulang yang menghancurkan tombol yang baru diklik, lalu menge-style tombol yang sudah mati → highlight seleksi tidak pernah terlihat + rebuild list tiap klik (spam InvokeServer). Sekarang hanya reset style sibling + highlight, tanpa rebuild.
- **Spam network**: pencarian player memanggil `InvokeServer` setiap ketikan huruf. Ditambah debounce 0.25 detik.
- **Leak koneksi**: Heartbeat animasi stroke RGB tidak pernah di-disconnect setelah stroke hancur. Sekarang auto-disconnect.

### 4. `ACMv7.client.lua`
- **Lag per-frame**: status monitor melakukan `FindFirstChild("Status", true)` (pencarian rekursif seluruh panel) SETIAP FRAME. Di-throttle jadi 4x/detik dan hanya update saat teks berubah.

### 5. `MicParticles.client.lua`
- **Leak**: `AudioAnalyzer` global dibuat dan di-parent ke player tapi tidak pernah dipakai. Dihapus.
- **Leak**: entri `Connecteds` (Wire + Analyzer) tidak dibersihkan kalau player keluar tanpa event server. Ditambah `Players.PlayerRemoving` cleanup + nil-guard di `DisconnectOld`.

### 6. `DonationClient.client.lua`
- **Leak/churn**: animasi kedip "Loading" jalan `while true` selamanya walau label sudah hancur, dan membuat 2 objek Tween baru tiap 1.6 detik. Sekarang berhenti saat label di-destroy, tween dibuat sekali dan dipakai ulang, dan idle saat label tidak terlihat.

### 7. `PlayerAssets/Template/UIStroke/Script.server.lua`
- **Churn**: script ini di-clone per item booth; tiap loop membuat 2 Tween baru tiap 4 detik selamanya. Tween sekarang dibuat sekali dan dipakai ulang; loop berhenti kalau gradient hilang; `wait` → `task.wait`.

### 8. `PlayerAssets.lua`
- **Bug crash**: `#data.data` error kalau respons API tidak punya field `data` (nil index). Ditambah guard.
- **Bug crash**: `MarketplaceService:GetProductInfo` bisa throw untuk asset invalid dan mematikan seluruh loop booth. Dibungkus pcall.

### 9. `FishingSystem.client.lua`
- **Leak koneksi**: `registerFishTool` memasang `AncestryChanged:Connect` baru setiap kali tool yang sama di-register ulang (terjadi tiap pencarian cache miss). Ditambah guard supaya hanya sekali per tool.

### 10. `ScreenGuuii/LocalNuke.client.lua`
- **Leak**: clone template ConfettiBox (`v14`) tidak pernah di-Destroy setelah sequence nuke selesai. Ditambah destroy di akhir.

### 11. `Module/GlobalFunction.lua` & `ScreenGuuii/Event.client.lua`
- **Bug**: variabel `k` bocor ke global environment di fungsi format angka (rawan konflik antar script). Dijadikan `local`.

## Duplikat yang Dihapus (49 file)

- **TopbarPlus/** (seluruh folder, termasuk `READ_ME`): duplikat byte-identik dari `Icon` — library TopbarPlus tersimpan 3x persis sama. Disisakan satu: `Icon.lua` + `Icon/` (yang dipakai `NametagRole` via `ReplicatedStorage.Icon`).
- **Packages/Icon.lua + Packages/Icon/**: duplikat identik yang sama, dihapus.
- **uxpRS/AdminPanel/Icon** TIDAK dihapus — versi berbeda (lebih lama) dan di-require secara relatif oleh AdminPanel.
- **ScreenGuuii/UltraAnimation/CameraShaker/CameraShaker*** (nested rekursif): hasil paste dobel — CameraShaker berisi copy dirinya sendiri 2 level. Modul hanya butuh `CameraShakeInstance` + `CameraShakePresets` sebagai child langsung; copy nested dihapus.

## Catatan Struktur

- Ekstensi file: `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript.
- Path folder = hierarki instance di rbxm asli. `_manifest.json` berisi mapping lengkap (nama, class, path).
- Library vendor (Promise, ProfileStore, HashLib, Janitor, GoodSignal, Icon/TopbarPlus, spr) tidak dimodifikasi — sudah battle-tested.
