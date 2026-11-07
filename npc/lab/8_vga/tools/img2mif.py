#!/usr/bin/env python3
import sys
from PIL import Image

W, H = 640, 480
ROWS = 512


def load_rgb(path):
    img = Image.open(path)
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        img = img.convert("RGBA")
        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
        img = Image.alpha_composite(bg, img)
    return img.convert("RGB")


def fit(path):
    img = load_rgb(path)
    scale = min(W / img.width, H / img.height)
    nw, nh = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    img = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    canvas.paste(img, ((W - nw) // 2, (H - nh) // 2))
    return canvas


def pack(r, g, b, bits):
    if bits == 24:
        return (r << 16) | (g << 8) | b
    return ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)


def main():
    if len(sys.argv) < 3:
        print("usage: img2mif.py <image> <output-prefix> [12|24]")
        sys.exit(1)
    src, out = sys.argv[1], sys.argv[2]
    bits = int(sys.argv[3]) if len(sys.argv) > 3 else 24
    if bits not in (12, 24):
        print("bits must be 12 or 24")
        sys.exit(1)

    im = fit(src)
    px = im.load()

    vals = []
    for x in range(W):
        for y in range(ROWS):
            if y < H:
                r, g, b = px[x, y]
            else:
                r = g = b = 255
            vals.append(pack(r, g, b, bits))

    digits = 6 if bits == 24 else 3
    with open(out + ".hex", "w") as f:
        f.write("@000000\n")
        for v in vals:
            f.write("%0*X\n" % (digits, v))

    with open(out + ".mif", "w") as f:
        f.write("DEPTH = %d;\n" % (W * ROWS))
        f.write("WIDTH = %d;\n\n" % bits)
        f.write("ADDRESS_RADIX = HEX;\n")
        f.write("DATA_RADIX = HEX;\n\n")
        f.write("CONTENT BEGIN\n")
        for i, v in enumerate(vals):
            f.write("%05X : %0*X;\n" % (i, digits, v))
        f.write("END;\n")

    print("%s -> %s.hex / %s.mif (%d words, %d bit)" % (src, out, out, len(vals), bits))


if __name__ == "__main__":
    main()
