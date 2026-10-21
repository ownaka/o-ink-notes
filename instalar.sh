#!/usr/bin/env bash
# Instala (ou atualiza) os dois plasmoides do O-Ink Notes.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROLLER="$DIR/net.ownaka.oinknotes"
NOTE="$DIR/net.ownaka.oinknote"
SHARED="$DIR/shared-qml"

echo "== Copiando código compartilhado pros dois pacotes =="
for pkg in "$CONTROLLER" "$NOTE"; do
    dest="$pkg/contents/ui/shared"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$SHARED"/. "$dest"/
done

install_or_update() {
    local pkg="$1"
    local id
    id="$(basename "$pkg")"
    if [ -d "$HOME/.local/share/plasma/plasmoids/$id" ]; then
        echo "== Atualizando $id =="
        kpackagetool6 -t Plasma/Applet -u "$pkg"
    else
        echo "== Instalando $id =="
        kpackagetool6 -t Plasma/Applet -i "$pkg"
    fi
}

install_or_update "$CONTROLLER"
install_or_update "$NOTE"

echo
echo "Pronto. Pra ver os widgets atualizados pode ser preciso reiniciar o plasmashell:"
echo "  systemctl --user restart plasma-plasmashell"
