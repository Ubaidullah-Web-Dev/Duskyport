# Dynamic Material 3 Theming with Matugen

Duskyport features first-class integration with **Matugen**, Google's Material You / Material Design 3 color extraction tool.

---

## 🎨 How it Works

1. **Template Specification**: The template file is located at [`matugen/duskyport.json`](../matugen/duskyport.json) and installed system-wide to `/usr/share/duskyport/matugen/duskyport.json`.
2. **Registration**: When Duskyport is installed, it registers an entry in `~/.config/matugen/config.toml`:

```toml
[templates.duskyport]
input_path  = '/usr/share/duskyport/matugen/duskyport.json'
output_path = '~/.config/duskyport/skins/matugen/skin.json'
```

3. **Live Syncing**: The `Tokens.qml` singleton monitors `~/.config/duskyport/skins/matugen/skin.json`. Whenever a wallpaper change or theme regeneration triggers `matugen`, Duskyport receives the updated color tokens instantly without needing an application restart.

---

## 🔄 Manually Regenerating the Theme

You can re-trigger Matugen generation for Duskyport at any time:

### From an Image/Wallpaper
```bash
matugen image ~/Pictures/Wallpapers/my-wallpaper.png
```

### From a Hex Color
```bash
matugen color hex '#2d3136'
```

---

## 🖌️ Material 3 Roles Mapping

| Role | Dusky Token | Description |
| :--- | :--- | :--- |
| `surface` | `Tokens.paper` | Main window background |
| `surface_container_low` | `Tokens.paperLift` | Card, sidebar, and container background |
| `on_surface` | `Tokens.ink` | High-contrast text and foreground elements |
| `on_surface_variant` | `Tokens.inkDim` | Muted and secondary labels |
| `primary` | `Tokens.bone` / `Tokens.sun` | Primary brand accent and interactive focus |
| `on_primary` | `Tokens.inkOnBone` | Text on active accent buttons |
| `error` | `Tokens.alert` | Failure states, shutdown notices, warnings |
