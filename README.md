# godot-web-preview

Godot 4.6.2 web-preview copy of the Hoomans Are Gone 2D top-down survival roguelite prototype.

The project includes the full single-run loop, player combat, enemy scaling, boss pressure points, upgrades, meta progression, generated PNG assets, and smoke tests.

## Development

Generate deterministic art assets:

```powershell
C:\Users\fengbo\Developer\godot\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tools/generate_assets.gd
```

Run the smoke test:

```powershell
C:\Users\fengbo\Developer\godot\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/smoke.gd
```

Build the Web export locally:

```powershell
New-Item -ItemType Directory -Force build\web
C:\Users\fengbo\Developer\godot\Godot_v4.6.2-stable_win64_console.exe --headless --path . --export-release Web build/web/index.html
Copy-Item deploy\_headers build\web\_headers
```

The `Web Preview` GitHub Actions workflow builds the same export for every pull request. Pushes to `main` also deploy the exported `build/web` directory through GitHub Pages when the repository is configured to use Actions as the Pages source.

GitHub Pages does not apply `deploy/_headers`; that file is for hosts such as Cloudflare Pages or Netlify. The current export is single-threaded, so it does not require COOP/COEP headers.
