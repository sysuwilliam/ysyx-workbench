#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont

W, H = 640, 480
BARS = [(255, 255, 255), (255, 255, 0), (0, 255, 255), (0, 255, 0),
        (255, 0, 255), (255, 0, 0), (0, 0, 255), (0, 0, 0)]

img = Image.new("RGB", (W, H), (0, 0, 0))
d = ImageDraw.Draw(img)

bw = W // len(BARS)
for i, c in enumerate(BARS):
    d.rectangle([i * bw, 0, (i + 1) * bw - 1, 359], fill=c)

for y in range(360, H):
    v = int(255 * (y - 360) / (H - 360))
    d.line([(0, y), (W - 1, y)], fill=(v, v, v))

d.rectangle([0, 0, W - 1, H - 1], outline=(255, 255, 255))
d.line([(W // 2, 0), (W // 2, H - 1)], fill=(96, 96, 96))
d.line([(0, H // 2), (W - 1, H // 2)], fill=(96, 96, 96))

font = None
for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
          "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
    try:
        font = ImageFont.truetype(p, 34)
        break
    except Exception:
        pass

text = "VGA 640x480"
tw = d.textlength(text, font=font) if font else len(text) * 18
d.rectangle([(W - tw) / 2 - 16, 286, (W + tw) / 2 + 16, 338], fill=(0, 0, 0))
d.text(((W - tw) / 2, 292), text, fill=(255, 255, 255), font=font)

img.save("resource/testcard.png")
print("resource/testcard.png")
