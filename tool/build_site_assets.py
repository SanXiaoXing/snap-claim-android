"""把仓库里的原始素材压缩成站点用的网页尺寸资源。

源图（assets/ 下）是给 App / README 用的高分辨率 PNG，直接丢到网页上会有
1MB+ 的体积，手机上首屏加载慢得离谱。这里统一降采样并转成 WebP（附带 JPEG 兜底），
同时生成圆角图标与 Open Graph 分享图。

用法：
    python tool/build_site_assets.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets"
OUT = ROOT / "site" / "assets"


def resize_to_width(img: Image.Image, width: int) -> Image.Image:
    if img.width <= width:
        return img.copy()
    height = round(img.height * width / img.width)
    return img.resize((width, height), Image.LANCZOS)


def rounded(img: Image.Image, radius_ratio: float = 0.22) -> Image.Image:
    """切成圆角（应用图标观感）：角落透明，深浅两套主题下都好看。"""
    img = img.convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.width - 1, img.height - 1),
        radius=round(min(img.size) * radius_ratio),
        fill=255,
    )
    img.putalpha(mask)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    # 首屏主视觉：保留 16:9，宽度压到 1400，WebP 为主 + JPEG 兜底。
    hero = Image.open(SRC / "img" / "hero.png").convert("RGB")
    hero = resize_to_width(hero, 1400)
    hero.save(OUT / "hero.webp", "WEBP", quality=82, method=6)
    hero.save(OUT / "hero.jpg", "JPEG", quality=82, optimize=True, progressive=True)

    # 导航栏 / 关于区的品牌标识：192 圆角图标 + 64 的 favicon。
    logo = Image.open(SRC / "icon" / "logo.png")
    rounded(resize_to_width(logo, 192)).save(OUT / "logo-192.png", optimize=True)
    rounded(resize_to_width(logo, 64)).save(OUT / "favicon-64.png", optimize=True)

    # 社交分享缩略图：1200x630，从主视觉中心裁切。
    og = Image.open(SRC / "img" / "hero.png").convert("RGB")
    og = resize_to_width(og, 1200)
    top = max(0, (og.height - 630) // 2)
    og.crop((0, top, 1200, min(og.height, top + 630))).save(
        OUT / "og.jpg", "JPEG", quality=84, optimize=True, progressive=True
    )

    for f in sorted(OUT.iterdir()):
        print(f"{f.name:16} {f.stat().st_size / 1024:7.1f} KB")


if __name__ == "__main__":
    main()
