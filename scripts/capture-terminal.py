#!/usr/bin/env python3
"""Render an actual saved tmux ANSI screen as a PNG and optional HTML.

Dependencies: python -m pip install pillow pyte
Capture (inside WSL): tmux capture-pane -e -p -t SESSION:0.0 > view.ansi
Render: python scripts/capture-terminal.py view.ansi view.png --html view.html

This tool does not generate or modify dashboard values. It emulates the saved
screen at the specified terminal dimensions, then paints each terminal cell.
The image footer identifies this as a render, not a desktop screenshot.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import math
from pathlib import Path

import pyte
from PIL import Image, ImageDraw, ImageFont


PALETTE = {
    "black": "#121820", "red": "#f97583", "green": "#85d99b",
    "brown": "#f6c177", "blue": "#79b8ff", "magenta": "#b392f0",
    "cyan": "#6edada", "white": "#e6edf3", "brightblack": "#7d8590",
    "brightred": "#ff9b9b", "brightgreen": "#b1f1a5", "brightbrown": "#ffe6a0",
    "brightblue": "#a3ceff", "brightmagenta": "#d8b9ff",
    "brightcyan": "#b3ffff", "brightwhite": "#ffffff",
}
BACKGROUND = "#0d1117"
FOREGROUND = "#e6edf3"


def color(value: str, default: str) -> str:
    if value == "default":
        return default
    if value in PALETTE:
        return PALETTE[value]
    if len(value) == 6 and all(c in "0123456789abcdefABCDEF" for c in value):
        return "#" + value
    return default


def cell_colors(cell) -> tuple[str, str]:
    foreground = color(cell.fg, FOREGROUND)
    background = color(cell.bg, BACKGROUND)
    return (background, foreground) if cell.reverse else (foreground, background)


def find_font(requested: str | None) -> Path:
    candidates = [Path(requested)] if requested else [
        Path("C:/Windows/Fonts/consola.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
        Path("/usr/share/fonts/truetype/liberation2/LiberationMono-Regular.ttf"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise SystemExit("A monospace TrueType font is required; provide --font PATH.")


def font_variants(path: Path, size: int) -> dict[str, ImageFont.FreeTypeFont]:
    names = {
        "consola.ttf": ("consolab.ttf", "consolai.ttf", "consolaz.ttf"),
        "DejaVuSansMono.ttf": ("DejaVuSansMono-Bold.ttf", "DejaVuSansMono-Oblique.ttf", "DejaVuSansMono-BoldOblique.ttf"),
        "LiberationMono-Regular.ttf": ("LiberationMono-Bold.ttf", "LiberationMono-Italic.ttf", "LiberationMono-BoldItalic.ttf"),
    }
    variants = {"regular": ImageFont.truetype(str(path), size)}
    for key, filename in zip(("bold", "italic", "bolditalic"), names.get(path.name, ())):
        candidate = path.with_name(filename)
        variants[key] = ImageFont.truetype(str(candidate), size) if candidate.is_file() else variants["regular"]
    for key in ("bold", "italic", "bolditalic"):
        variants.setdefault(key, variants["regular"])
    return variants


def render_png(screen, output: Path, title: str, source_hash: str, fonts, font_size: int) -> None:
    padding, header, footer = 24, 62, 50
    cell_width = math.ceil(fonts["regular"].getlength("M"))
    cell_height = math.ceil(font_size * 1.4)
    width = screen.columns * cell_width + padding * 2
    height = screen.lines * cell_height + header + footer
    canvas = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, width, header - 10), fill="#161b22")
    draw.text((padding, 12), title, font=fonts["bold"], fill=FOREGROUND)
    draw.text((padding, 33), f"Saved live terminal screen | {screen.columns} columns x {screen.lines} rows", font=fonts["regular"], fill="#8b949e")
    for row in range(screen.lines):
        for column in range(screen.columns):
            cell = screen.buffer[row][column]
            fg, bg = cell_colors(cell)
            x, y = padding + column * cell_width, header + row * cell_height
            if bg != BACKGROUND:
                draw.rectangle((x, y, x + cell_width - 1, y + cell_height - 1), fill=bg)
            if cell.data and cell.data != " ":
                key = "bolditalic" if cell.bold and cell.italics else "bold" if cell.bold else "italic" if cell.italics else "regular"
                draw.text((x, y), cell.data, font=fonts[key], fill=fg)
            if cell.underscore:
                draw.line((x, y + cell_height - 3, x + cell_width - 1, y + cell_height - 3), fill=fg)
            if cell.strikethrough:
                draw.line((x, y + cell_height // 2, x + cell_width - 1, y + cell_height // 2), fill=fg)
    footer_top = header + screen.lines * cell_height + 7
    draw.text((padding, footer_top), "Rendered from the saved tmux ANSI capture; dashboard values unchanged.", font=fonts["regular"], fill="#8b949e")
    draw.text((padding, footer_top + 20), "Capture SHA-256: " + source_hash, font=fonts["regular"], fill="#8b949e")
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)


def render_html(screen, output: Path, title: str, source_hash: str, font_size: int) -> None:
    rows = []
    for row in range(screen.lines):
        spans = []
        active_style = None
        run = ""
        for column in range(screen.columns):
            cell = screen.buffer[row][column]
            if not cell.data:  # continuation cell of a double-width glyph
                continue
            fg, bg = cell_colors(cell)
            decorations = []
            if cell.underscore:
                decorations.append("underline")
            if cell.strikethrough:
                decorations.append("line-through")
            style = f"color:{fg};background:{bg};font-weight:{'bold' if cell.bold else 'normal'};font-style:{'italic' if cell.italics else 'normal'};text-decoration:{' '.join(decorations) or 'none'}"
            if active_style is not None and style != active_style:
                spans.append(f'<span style="{active_style}">{html.escape(run)}</span>')
                run = ""
            active_style = style
            run += cell.data
        if active_style is not None:
            spans.append(f'<span style="{active_style}">{html.escape(run)}</span>')
        rows.append("".join(spans))
    document = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title><style>
body{{margin:0;padding:24px;background:{BACKGROUND};color:{FOREGROUND};font-family:system-ui,sans-serif}}
h1{{font-size:20px;margin:0 0 8px}}p{{color:#8b949e;font-size:13px}}
pre{{font-family:Consolas,"DejaVu Sans Mono",monospace;font-size:{font_size}px;line-height:1.4;white-space:pre;width:max-content}}
code{{overflow-wrap:anywhere}}
</style></head><body><h1>{html.escape(title)}</h1>
<p>Actual saved live terminal screen: {screen.columns} columns × {screen.lines} rows. Rendered from tmux ANSI capture; dashboard values unchanged.</p>
<pre aria-label="Captured terminal output">{chr(10).join(rows)}</pre>
<p>Capture SHA-256: <code>{source_hash}</code></p></body></html>
'''
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(document, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", type=Path, help="UTF-8 tmux capture-pane -e -p output")
    parser.add_argument("output", type=Path, help="output PNG path")
    parser.add_argument("--html", type=Path, help="also write an inspectable HTML rendering")
    parser.add_argument("--title", default="kdash live terminal capture")
    parser.add_argument("--columns", type=int, default=170)
    parser.add_argument("--rows", type=int, default=50)
    parser.add_argument("--font", help="path to a monospace TrueType font")
    parser.add_argument("--font-size", type=int, default=16)
    args = parser.parse_args()
    if args.columns <= 0 or args.rows <= 0 or args.font_size <= 0:
        parser.error("columns, rows, and font-size must be positive")
    raw = args.input.read_bytes()
    source_hash = hashlib.sha256(raw).hexdigest()
    captured_text = raw.decode("utf-8-sig").replace("\r\n", "\n")
    # capture-pane serializes each screen row with LF. Strip its final delimiter
    # to avoid scrolling an otherwise complete screen, and reset the column on LF.
    captured_text = captured_text.removesuffix("\n").replace("\n", "\r\n")
    if captured_text.count("\n") + 1 > args.rows:
        parser.error("capture contains more rows than --rows; use the original tmux pane height")
    screen = pyte.Screen(args.columns, args.rows)
    pyte.Stream(screen).feed(captured_text)
    fonts = font_variants(find_font(args.font), args.font_size)
    render_png(screen, args.output, args.title, source_hash, fonts, args.font_size)
    if args.html:
        render_html(screen, args.html, args.title, source_hash, args.font_size)
    print(f"Rendered {args.input} -> {args.output} ({args.columns}x{args.rows}; SHA-256 {source_hash})")


if __name__ == "__main__":
    main()
