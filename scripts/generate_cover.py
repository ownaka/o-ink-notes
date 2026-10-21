#!/usr/bin/env python3
"""
Gera assets/cover.png: a capa do README (e prévia de link do GitHub).

Uso:
    python3 scripts/generate_cover.py

Precisa da fonte Commit Mono instalada (SIL Open Font License) e dos
prints em assets/screenshots/popup-nota-aberta.png e
assets/screenshots/nota-fixada.png (gerados durante o desenvolvimento).
"""

import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
SCREENSHOTS = os.path.join(ASSETS, "screenshots")
OUTPUT = os.path.join(ASSETS, "cover.png")

WIDTH, HEIGHT = 1280, 640

BG = "#0c0c0c"
DOT = "#232323"
TEXT = "#e6e1d5"
SECONDARY = "#888477"
BORDER = "#2e2e2e"
ACCENT = "#689d6a"

FONT_CANDIDATES_REGULAR = [
    os.path.expanduser("~/.local/share/fonts/CommitMono/CommitMono-Regular.ttf"),
    "/usr/share/fonts/CommitMono/CommitMono-Regular.ttf",
]
FONT_CANDIDATES_BOLD = [
    os.path.expanduser("~/.local/share/fonts/CommitMono/CommitMono-Bold.ttf"),
    "/usr/share/fonts/CommitMono/CommitMono-Bold.ttf",
]


def find_font(candidates, size):
    for path in candidates:
        if os.path.isfile(path):
            return ImageFont.truetype(path, size)
    raise FileNotFoundError(
        "Commit Mono não encontrada. Baixe em https://commitmono.com/ "
        "(SIL Open Font License) e instale em ~/.local/share/fonts/CommitMono/."
    )


def draw_dots(draw, spacing=24, radius=1.2):
    for x in range(spacing // 2, WIDTH, spacing):
        for y in range(spacing // 2, HEIGHT, spacing):
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=DOT)


def draw_trigram(draw, x, y, w, h, bar_h, gap, color):
    """☵ — trigrama Kan: barra do meio inteira, as duas de fora partidas."""
    rows = [
        y,
        y + bar_h + gap,
        y + 2 * (bar_h + gap),
    ]
    # linha de cima: partida
    draw.rectangle([x, rows[0], x + w * 0.42, rows[0] + bar_h], fill=color)
    draw.rectangle([x + w * 0.58, rows[0], x + w, rows[0] + bar_h], fill=color)
    # linha do meio: inteira
    draw.rectangle([x, rows[1], x + w, rows[1] + bar_h], fill=color)
    # linha de baixo: partida
    draw.rectangle([x, rows[2], x + w * 0.42, rows[2] + bar_h], fill=color)
    draw.rectangle([x + w * 0.58, rows[2], x + w, rows[2] + bar_h], fill=color)


def paste_with_border(base, img_path, x, y, target_w, border_color=BORDER, border_w=1):
    img = Image.open(img_path).convert("RGB")
    ratio = target_w / img.width
    target_h = round(img.height * ratio)
    img = img.resize((target_w, target_h), Image.LANCZOS)
    base.paste(img, (x, y))
    draw = ImageDraw.Draw(base)
    draw.rectangle(
        [x, y, x + target_w - 1, y + target_h - 1],
        outline=border_color,
        width=border_w,
    )
    return target_w, target_h


def main():
    img = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(img)
    draw_dots(draw)

    title_font = find_font(FONT_CANDIDATES_BOLD, 64)
    subtitle_font = find_font(FONT_CANDIDATES_REGULAR, 24)

    margin_x = 64

    draw_trigram(draw, margin_x, 120, 72, 44, 10, 7, ACCENT)

    draw.text((margin_x, 210), "O-Ink Notes", font=title_font, fill=TEXT)

    subtitle = "notas em Markdown no seu desktop KDE, 100% local"
    draw.text((margin_x, 300), subtitle, font=subtitle_font, fill=SECONDARY)

    # screenshots à direita, compostos em camadas
    popup_path = os.path.join(SCREENSHOTS, "popup-nota-aberta.png")
    note_path = os.path.join(SCREENSHOTS, "nota-fixada.png")

    if os.path.isfile(popup_path):
        paste_with_border(img, popup_path, 760, 55, 400)
    if os.path.isfile(note_path):
        paste_with_border(img, note_path, 660, 420, 280)

    os.makedirs(ASSETS, exist_ok=True)
    img.save(OUTPUT)
    print("Capa gerada em", OUTPUT)


if __name__ == "__main__":
    main()
