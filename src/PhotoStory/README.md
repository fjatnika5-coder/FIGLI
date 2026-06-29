# Photo Story / TikTok Cutscene UI

Cutscene portrait 9:16 berbasis **UI + ViewportFrame** (bukan kamera Workspace).
Dua avatar player tampil sebagai pasangan, dengan background, sticker, caption,
musik, dan transisi (fade / white flash / zoom / blur / slide / dark intro).

## Kenapa UI + ViewportFrame, bukan kamera Workspace?

- **Ringan & terisolasi.** ViewportFrame render mini-scene sendiri (Camera + WorldModel
  khusus). Tidak menyentuh `CurrentCamera`, tidak menggerakkan karakter asli di world,
  tidak mengganggu physics/streaming player lain.
- **Anti-konflik.** Tidak rebut kamera dengan sistem lain (freecam, spectate, default).
  Keluar cutscene = hapus ScreenGui; tidak ada kamera yang nyangkut `Scriptable`.
- **Responsive gratis.** Layout pakai `Scale` + `UIAspectRatioConstraint`, otomatis fit
  & letterbox 9:16 di PC/tablet/HP tanpa hitung viewport manual.
- **Murah di HP low-end.** Tidak ada `RenderStepped` permanen; transisi pakai `TweenService`.
  Hanya 1 AnimationTrack hidup per avatar → tidak kena limit 64.
- **Cleanup gampang.** Semua resource masuk Janitor; sekali destroy bersih total.

## Folder tree Roblox Studio

```
ReplicatedStorage
├── PhotoStoryConfig            (ModuleScript)
└── PhotoStoryRemotes           (Folder)  ← dibuat otomatis oleh server kalau belum ada
    ├── RequestStart            (RemoteEvent)
    ├── StartStory              (RemoteEvent)
    └── EndStory                (RemoteEvent)

ServerScriptService
├── PhotoStoryServer            (Script)
└── PhotoStoryTrigger           (Script)

StarterPlayer
└── StarterPlayerScripts
    ├── PhotoStoryClient        (LocalScript)
    └── Modules                 (Folder)
        ├── SceneRunner         (ModuleScript)
        ├── ViewportCharacter   (ModuleScript)
        ├── TransitionController (ModuleScript)
        ├── AssetPreloader      (ModuleScript)
        └── Janitor             (ModuleScript)
```

`Modules` HARUS anak dari `PhotoStoryClient` (LocalScript), karena client require
`script.Modules.SceneRunner`, dan modul saling require `script.Parent.X`.

## Setup di Studio

1. Buat `PhotoStoryConfig` (ModuleScript) di ReplicatedStorage, isi dari file config.
2. Buat `PhotoStoryServer` & `PhotoStoryTrigger` (Script) di ServerScriptService.
3. Buat `PhotoStoryClient` (LocalScript) di StarterPlayerScripts. Di dalamnya buat
   Folder `Modules`, lalu 5 ModuleScript di atas.
4. `PhotoStoryRemotes` + 3 RemoteEvent dibuat otomatis oleh server saat run
   (boleh juga dibuat manual; idempotent).
5. Buat Part pemicu di Workspace, beri nama sesuai `Config.PadPartName`
   (default `PhotoStoryPad`). Anchored = true.
6. Isi asset id di `PhotoStoryConfig`: `MusicSoundId`, `Background`, `Image`,
   `AnimationId`. Semua placeholder `..._ID` diabaikan otomatis (tidak error).

## Cara pakai

Dua player berdiri bareng di `PhotoStoryPad` → server validasi pasangan →
StartStory ke kedua client → cutscene jalan di tiap client. Selesai/keluar →
UI hilang, sound stop, semua track & clone & connection dibersihkan.

## Edit config (tanpa sentuh logic)

`PhotoStoryConfig.Scenes` array. Tiap scene: `Duration`, `Background`,
`TransitionIn/Out`, `Text` (Position/Size/Font/Color/Typewriter/Fade),
`Characters.Left/Right` (User PlayerA/PlayerB, Position, Scale, Rotation, AnimationId),
`Images` (Name, Image, Position, Size, Transparency). Global: `MusicSoundId`,
`Volume`, `AspectRatio`, `LowEndMode`, `AutoLowEnd`, `PadPartName`, `TextDefaults`.

Transisi: `Fade`, `FadeWhite`, `WhiteFlash`, `DarkIntro`, `Zoom`, `Blur`, `Slide`.

## Anti-lag & anti-leak

- Tidak ada `RenderStepped`/`while true` permanen. `_wait` pakai token cancellation.
- Semua connection/tween/instance/track masuk Janitor; `Cleanup` reverse-order.
- Tiap ganti animasi: track lama `Stop(0)` + `Destroy` → max 2 track hidup.
- Preload hanya scene sekarang + berikutnya (`AssetPreloader.preloadWindow`).
- `LowEndMode` (atau `AutoLowEnd` di mobile): blur/zoom/slide diturunkan jadi fade.
- Tidak ada spam print; hanya `warn` untuk error penting.

## Checklist testing

- [ ] **PC**: cutscene fit 9:16 center + letterbox; transisi & text mulus.
- [ ] **Mobile/tablet**: responsive, tidak keluar layar, aman notch (DeviceSafeInsets),
      tidak lag (auto low-end aktif).
- [ ] **Dua player start**: berdiri bareng di pad → kedua client jalan sinkron.
- [ ] **Player leave saat cutscene**: partner ikut berhenti, UI bersih, tidak error.
- [ ] **Replay berkali-kali**: keluar-masuk pad berulang; tidak ada ScreenGui/Sound sisa.
- [ ] **Memory leak**: cek tidak ada ViewportFrame/Sound/connection menumpuk setelah selesai.
- [ ] **AnimationTrack limit 64**: putar banyak scene berulang; track tidak menumpuk
      (selalu max 2 hidup).
- [ ] **Mouse/kamera**: kamera asli tidak berubah; tidak ada yang nyangkut setelah keluar.
