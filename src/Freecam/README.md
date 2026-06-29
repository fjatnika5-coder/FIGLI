# Hybrid Platform Freecam

Custom Roblox Freecam (Knit + Janitor) dengan routing per platform.

## Routing

| Platform | Deteksi | Behavior |
|----------|---------|----------|
| **Desktop / PC** | keyboard + mouse, bukan ten-foot | Roblox **native** developer freecam (Shift+P). Tidak ada custom runtime, tidak Scriptable, tidak bind `V`. Tombol UI hanya menampilkan label `Shift+P` + info kecil saat diklik. |
| **Mobile / Tablet** | touch-primary, bukan KB+M, bukan console | Custom freecam (movement UI, touch pan, zoom, hide, close, restore). |
| **Console** | ten-foot / gamepad-only | Custom freecam via gamepad. LeftThumbstick = gerak, RightThumbstick = pan, R2/L2 = naik/turun, R1/L1 = zoom, `Y` = toggle, `B` / tombol Close = exit. |

Laptop touchscreen punya keyboard+mouse → terdeteksi Desktop (bukan Mobile),
jadi tidak salah masuk custom freecam.

## Module

- `FreecamPlatform` — deteksi platform: `getMode`, `shouldUseCustomRuntime`, `shouldUseNativeRobloxFreecam`.
- `FreecamRuntime` — routing (`_bindDesktop` / `_bindCustom` / `_bindConsoleActions`), camera step, guard `Start/Stop/Toggle/Bind`, cleanup.
- `FreecamInput` — capture keyboard/mouse/touch/gamepad.
- `FreecamMobileUI` — visibility UI, close/hide selalu visible saat aktif, safe-area.
- `FreecamController` — Knit controller (entry point).
- `FreecamResolver` / `FreecamState` — tidak berubah.

## Struktur Studio (require paths)

Module ini disusun supaya `require` path cocok dengan tree Studio asli:

```
PlayerScripts
└── Client
    ├── Controllers/FreecamController
    └── Modules/Freecam/{FreecamRuntime, FreecamInput, FreecamMobileUI,
                          FreecamState, FreecamResolver, FreecamPlatform}
```

Folder `src/Freecam/` di repo ini hanya pencatatan; isi file siap paste ke Studio
(path `require` di dalam file mengikuti tree Studio, bukan layout repo).
