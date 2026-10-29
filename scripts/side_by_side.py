#!/usr/bin/env python3
"""Side-by-side PNG: official form page (left) vs our rendered page (right).

    python3 scripts/side_by_side.py OUT.png OFFICIAL.pdf OFFICIAL_PAGE OURS.pdf OURS_PAGE [title]
Needs pdftoppm (poppler) and Pillow.
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

H = 1100  # height of each page image


def page_png(pdf, page, tmp, tag):
    base = os.path.join(tmp, tag)
    subprocess.run(["pdftoppm", "-f", str(page), "-l", str(page), "-r", "110", "-png", "-singlefile", pdf, base], check=True)
    im = Image.open(base + ".png").convert("RGB")
    return im.resize((int(im.width * H / im.height), H), Image.LANCZOS)


def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def main():
    out, opdf, opage, upd, upage = sys.argv[1:6]
    title = sys.argv[6] if len(sys.argv) > 6 else ""
    with tempfile.TemporaryDirectory() as tmp:
        a, b = page_png(opdf, int(opage), tmp, "a"), page_png(upd, int(upage), tmp, "b")
    pad, head = 24, 70
    W = a.width + b.width + pad * 3
    canvas = Image.new("RGB", (W, H + head + pad), "#e9edf2")
    d = ImageDraw.Draw(canvas)
    d.text((pad, 10), title, fill="#111827", font=font(22))
    d.text((pad, 42), f"Official: {os.path.basename(opdf)} p.{opage}", fill="#374151", font=font(16))
    d.text((pad * 2 + a.width, 42), f"LicenseLogger: {os.path.basename(upd)} p.{upage}", fill="#1d4ed8", font=font(16))
    canvas.paste(a, (pad, head))
    canvas.paste(b, (pad * 2 + a.width, head))
    d.rectangle([pad - 1, head - 1, pad + a.width, head + H], outline="#9ca3af")
    d.rectangle([pad * 2 + a.width - 1, head - 1, pad * 2 + a.width + b.width, head + H], outline="#1d4ed8")
    canvas.save(out, optimize=True)


if __name__ == "__main__":
    main()
