#!/usr/bin/env bash
# Builds Pyrewake and installs it for the current user (Omarchy / any freedesktop Linux).
# Run from anywhere:  tools/install.sh
# Uninstall:          tools/install.sh --uninstall
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
APP_DIR="$HOME/.local/share/pyrewake"
BIN_LINK="$HOME/.local/bin/pyrewake"
DESKTOP="$HOME/.local/share/applications/pyrewake.desktop"
ICON="$HOME/.local/share/icons/hicolor/scalable/apps/pyrewake.svg"

# Remove an install made before 0.6.0, which used older paths
rm -rf "$HOME/.local/share/ashen-crown" "$HOME/.local/bin/ashen-crown" "$HOME/.local/share/applications/ashen-crown.desktop" "$HOME/.local/share/icons/hicolor/scalable/apps/ashen-crown.svg"

if [[ "${1:-}" == "--uninstall" ]]; then
	rm -rf "$APP_DIR" "$BIN_LINK" "$DESKTOP" "$ICON"
	command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
	echo "Pyrewake uninstalled."
	exit 0
fi

case "$(uname -m)" in
	aarch64 | arm64) ARCH="arm64" ;;
	x86_64) ARCH="x86_64" ;;
	*) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

GODOT="${GODOT:-$(command -v godot || true)}"
[[ -x "$GODOT" ]] || { echo "Godot not found. Set GODOT=/path/to/godot." >&2; exit 1; }

# Point the export preset at the right architecture, then build a single self-contained binary.
sed -i "/^\[preset.0.options\]/,/^\[preset.1\]/ s/^binary_format\/architecture=.*/binary_format\/architecture=\"$ARCH\"/" "$GAME/export_presets.cfg"
mkdir -p "$GAME/build"
OUT="$GAME/build/pyrewake.$ARCH"
echo "Building $OUT ..."
"$GODOT" --headless --path "$GAME" --export-release "Linux" "build/pyrewake.$ARCH" >/dev/null 2>&1
[[ -s "$OUT" ]] || { echo "Export failed (are the Godot export templates installed?)." >&2; exit 1; }

mkdir -p "$APP_DIR" "$(dirname "$BIN_LINK")" "$(dirname "$DESKTOP")" "$(dirname "$ICON")"
install -m 755 "$OUT" "$APP_DIR/pyrewake"
cp "$GAME/icon.svg" "$ICON"
ln -sf "$APP_DIR/pyrewake" "$BIN_LINK"

cat >"$DESKTOP" <<EOF
[Desktop Entry]
Name=Pyrewake
GenericName=Action RPG
Comment=Nothing stays buried.
Exec=$APP_DIR/pyrewake
Icon=pyrewake
Terminal=false
Type=Application
Categories=Game;ActionGame;RolePlaying;
StartupWMClass=Pyrewake
EOF

command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "Installed. Launch it from the app launcher (Super + Space) or run: pyrewake"
