#!/usr/bin/env bash
# Builds Ashen Crown and installs it for the current user (Omarchy / any freedesktop Linux).
# Run from anywhere:  tools/install.sh
# Uninstall:          tools/install.sh --uninstall
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
APP_DIR="$HOME/.local/share/ashen-crown"
BIN_LINK="$HOME/.local/bin/ashen-crown"
DESKTOP="$HOME/.local/share/applications/ashen-crown.desktop"
ICON="$HOME/.local/share/icons/hicolor/scalable/apps/ashen-crown.svg"

if [[ "${1:-}" == "--uninstall" ]]; then
	rm -rf "$APP_DIR" "$BIN_LINK" "$DESKTOP" "$ICON"
	command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
	echo "Ashen Crown uninstalled."
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
sed -i "s/^binary_format\/architecture=.*/binary_format\/architecture=\"$ARCH\"/" "$GAME/export_presets.cfg"
mkdir -p "$GAME/build"
OUT="$GAME/build/ashen-crown.$ARCH"
echo "Building $OUT ..."
"$GODOT" --headless --path "$GAME" --export-release "Linux" "build/ashen-crown.$ARCH" >/dev/null 2>&1
[[ -s "$OUT" ]] || { echo "Export failed (are the Godot export templates installed?)." >&2; exit 1; }

mkdir -p "$APP_DIR" "$(dirname "$BIN_LINK")" "$(dirname "$DESKTOP")" "$(dirname "$ICON")"
install -m 755 "$OUT" "$APP_DIR/ashen-crown"
cp "$GAME/icon.svg" "$ICON"
ln -sf "$APP_DIR/ashen-crown" "$BIN_LINK"

cat >"$DESKTOP" <<EOF
[Desktop Entry]
Name=Ashen Crown
GenericName=Action RPG
Comment=Nothing stays buried.
Exec=$APP_DIR/ashen-crown
Icon=ashen-crown
Terminal=false
Type=Application
Categories=Game;ActionGame;RolePlaying;
StartupWMClass=Ashen Crown
EOF

command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "Installed. Launch it from the app launcher (Super + Space) or run: ashen-crown"
