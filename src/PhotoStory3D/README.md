# Photo Story 3D — Cinematic Camera Cutscene

Revisi dari versi UI-ViewportFrame. Sekarang **3D camera scene** di Workspace:
kamera client diarahkan ke `CameraPart` tiap scene, avatar (otomatis dari player
yang injek pad) ditaruh di `GirlPoint`/`BoyPoint`, dengan caption, musik, transisi
(fade/flash/blur/vignette), camera shake lembut + slow zoom — mirip edit TikTok.

> Menggantikan folder `src/PhotoStory/` (versi lama). Pakai salah satu, jangan dua-duanya.

## Arsitektur

- **Avatar = clone visual lokal (client-only).** Dibangun dari `UserId` player yang
  injek pad (lewat `GetHumanoidDescriptionFromUserId`), bukan UserId di config.
  Clone diparent ke Workspace **di client** → tidak replikasi, tidak desync, tidak
  ganggu player lain. Char asli tidak dipindah; cukup di-**freeze** server + di-**hide**
  lokal supaya tidak ada avatar duplikat di frame. Cleanup = destroy clone.
- **Server** = pad detection (GirlPad/BoyPad), pairing, validasi character, freeze
  (`WalkSpeed/JumpPower/JumpHeight=0`, `AutoRotate=false`, anchor HRP, simpan +
  restore CFrame), state, StartStory/EndStory.
- **Client** = kamera Scriptable → CameraPart, posisi clone, animasi, caption UI,
  musik, transisi, shake/zoom. Satu `BindToRenderStep` hanya untuk shake+zoom,
  di-unbind saat cleanup.
- **Anti-leak**: semua connection/tween/instance/track/clone/effect → Janitor.
  Tiap ganti animasi: track lama `Stop(0)`+`Destroy` → maks 1 track/avatar (aman 64).

## Folder tree Roblox Studio

```
ReplicatedStorage
├── PhotoStoryConfig            ModuleScript
└── PhotoStoryRemotes           Folder (auto-created server)
    ├── StartStory  RemoteEvent
    └── EndStory    RemoteEvent

ServerScriptService
└── PhotoStoryServer            Script

StarterPlayer/StarterPlayerScripts
├── PhotoStoryClient            LocalScript
└── Modules                     Folder
    ├── Janitor                 ModuleScript
    ├── AvatarClone             ModuleScript
    ├── CameraDirector          ModuleScript
    ├── TransitionController    ModuleScript
    └── CutsceneRunner          ModuleScript
```

`Modules` = anak dari `PhotoStoryClient`.

## Setup Workspace

```
Workspace
├── PhotoPads                   Folder (atau Model)
│   ├── GirlPad                 Part (Anchored, CanTouch on)
│   └── BoyPad                  Part (Anchored, CanTouch on)
└── PhotoStoryScenes            Folder
    ├── Scene1
    │   ├── CameraPart          Part (Anchored, Transparency 1, CanCollide off)
    │   ├── GirlPoint           Part (Anchored, Transparency 1, CanCollide off)
    │   └── BoyPoint            Part (Anchored, Transparency 1, CanCollide off)
    ├── Scene2  ( CameraPart / GirlPoint / BoyPoint )
    └── Scene3  ( CameraPart / GirlPoint / BoyPoint )
```

- **CameraPart**: arah kamera = **front face** part (`-Z`/lookVector). Putar part
  untuk menentukan sudut kamera. Kamera diam di posisi part lalu dolly maju pelan.
- **GirlPoint / BoyPoint**: posisi + arah hadap avatar = orientasi part. Avatar di-pivot
  ke `part.CFrame` (kaki ≈ titik pivot HumanoidRootPart, jadi taruh point setinggi pinggang
  atau sesuaikan tinggi part).
- Nama folder/pad bisa diganti di `Config` (`ScenesFolder`, `PadsFolder`,
  `GirlPadName`, `BoyPadName`).

## Setting tiap scene (Config.Scenes)

| Field | Arti |
|-------|------|
| `Name` | nama folder scene di `PhotoStoryScenes` |
| `Duration` | lama scene (detik) |
| `CameraPart` / `GirlPoint` / `BoyPoint` | nama part di dalam folder scene |
| `Camera.FOV` | field of view scene |
| `Camera.Shake` / `ShakeAmount` | shake on/off + kekuatan (rad, mis. 0.05–0.1) |
| `Camera.SlowZoom` / `ZoomAmount` | dolly maju on/off + jarak (stud) |
| `Animations.Girl` / `Boy` | animation id per scene (placeholder di-skip) |
| `Text.Text` | caption |
| `Text.StartTime` | delay sebelum caption muncul (detik dalam scene) |
| `Text.Typewriter` / `Fade` / `Bounce` | efek caption |
| `Vignette` | true = fade-in vignette (butuh `Config.VignetteImage`) |
| `TransitionIn` / `TransitionOut` | `FadeBlack`, `FadeWhite`, `FlashWhite`, `Blur` |

Global: `MusicSoundId`, `Volume`, `LowEndMode`, `AutoLowEnd`, `VignetteImage`,
`TextDefaults`.

## Efek mirip video referensi

- **Camera shake** lembut via `math.noise` (mulus, tidak loncat).
- **Slow zoom** = dolly maju ease-out sepanjang scene.
- **White flash** = `FlashWhite` (spike putih cepat 0.12s).
- **Fade in/out** = `FadeBlack` / `FadeWhite`.
- **Blur** = `BlurEffect` Lighting (di-reset antar scene; off di LowEnd).
- **Text pop/bounce** = UIScale `EasingStyle.Back` + typewriter + fade.
- **Vignette** opsional (asset id sendiri).

## Anti-lag & anti-leak

- Tidak ada `while true`/RenderStepped permanen kecuali satu untuk shake+zoom
  (di-unbind via janitor saat cleanup).
- Track animasi selalu `Stop(0)`+`Destroy` saat ganti/selesai → tidak kena limit 64.
- Clone, camera state, blur, sound, UI, connection, tween → semua di Janitor.
- `LowEndMode`/`AutoLowEnd` (mobile): shake×0.4, zoom×0.6, blur off, vignette off.
- Tidak ada print/debug; hanya `warn` untuk error penting (pad tidak ketemu).

## Edge case yang ditangani (server)

- Player leave saat cutscene → `endSession` → partner dapat EndStory + di-unfreeze.
- Character mati/reset → `CharacterRemoving` → sesi diakhiri (tidak coba restore char hilang).
- Player keluar pad sebelum mulai → occupancy turun, tidak start.
- Replay berkali → state per-player + cooldown; clone/UI lama dibersihkan dulu.
- Banyak pasangan barengan → `isBusy` cegah double; satu pasang per pad-set.
- Spam trigger → `COOLDOWN` 4s + busy check.

## Checklist testing

**PC**
- [ ] GirlPad + BoyPad terinjak dua player → cutscene mulai di kedua client.
- [ ] Kamera pindah ke CameraPart tiap scene; shake & slow zoom mulus.
- [ ] Caption muncul (typewriter/fade/bounce) dengan timing benar.
- [ ] Transisi FadeWhite/FlashWhite/Blur/FadeBlack smooth, tidak patah.
- [ ] Selesai → kamera normal, kontrol balik, animasi stop, clone hilang, char asli muncul lagi.

**Mobile/tablet**
- [ ] Responsive, caption tidak keluar layar (DeviceSafeInsets).
- [ ] AutoLowEnd aktif: efek berat turun, tetap smooth, tidak lag.
- [ ] Kontrol ter-disable saat cutscene, balik normal setelah.

**Stabilitas**
- [ ] Salah satu player leave saat cutscene → partner berhenti bersih, tidak error.
- [ ] Character reset saat cutscene → sesi berakhir, tidak nyangkut Scriptable.
- [ ] Replay 10×: tidak ada clone/Sound/BlurEffect/connection menumpuk.
- [ ] AnimationTrack maks 2 hidup (1 per avatar); tidak ada warning limit 64.
- [ ] Tidak ada player stuck freeze setelah cutscene.
