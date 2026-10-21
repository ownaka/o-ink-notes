#!/usr/bin/env bash
# Remove os dois plasmoides do O-Ink Notes.
# Não apaga suas notas nem suas configurações (ficam em
# ~/.local/share/o-ink-notes e ~/.config/o-ink-notes).
set -euo pipefail

kpackagetool6 -t Plasma/Applet -r net.ownaka.oinknotes || true
kpackagetool6 -t Plasma/Applet -r net.ownaka.oinknote || true

echo
echo "Plasmoides removidos. Suas notas continuam em ~/.local/share/o-ink-notes/notes"
echo "Se quiser apagar tudo também: rm -rf ~/.local/share/o-ink-notes ~/.config/o-ink-notes"
