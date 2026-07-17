#!/usr/bin/env python3
"""生成 FileConverter.icns"""

import os
import subprocess
from pathlib import Path

def create_png(size, output_path):
    """用 Python 生成纯色圆形 PNG"""
    import struct, zlib

    pixels = []
    for y in range(size):
        row = []
        for x in range(size):
            ratio = y / size
            r = int(30 + 20 * ratio)
            g = int(100 + 50 * ratio)
            b = int(200 + 30 * ratio)
            a = 255

            cx, cy = size // 2, size // 2
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dist > size * 0.45:
                a = 0

            row.extend([r, g, b, a])
        pixels.append(bytes([0] + row))

    def png_chunk(chunk_type, data):
        chunk_len = struct.pack('>I', len(data))
        chunk_crc = struct.pack('>I', zlib.crc32(chunk_type + data) & 0xffffffff)
        return chunk_len + chunk_type + data + chunk_crc

    png_data = b'\x89PNG\r\n\x1a\n'
    png_data += png_chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    png_data += png_chunk(b'IDAT', zlib.compress(b''.join(pixels), 9))
    png_data += png_chunk(b'IEND', b'')

    with open(output_path, 'wb') as f:
        f.write(png_data)

def main():
    iconset = Path("FileConverter.iconset")
    iconset.mkdir(exist_ok=True)

    sizes = {
        'icon_16x16.png': 16,
        'icon_16x16@2x.png': 32,
        'icon_32x32.png': 32,
        'icon_32x32@2x.png': 64,
        'icon_128x128.png': 128,
        'icon_128x128@2x.png': 256,
        'icon_256x256.png': 256,
        'icon_256x256@2x.png': 512,
        'icon_512x512.png': 512,
        'icon_512x512@2x.png': 1024,
    }

    print("🎨 生成图标...")
    for name, size in sizes.items():
        path = iconset / name
        create_png(size, path)
        print(f"  ✅ {name} ({size}x{size})")

    print("\n💿 转换为 icns...")
    result = subprocess.run(
        ['iconutil', '-c', 'icns', str(iconset), '-o', 'FileConverter.icns'],
        capture_output=True
    )

    if result.returncode == 0:
        print("✅ FileConverter.icns 生成成功！")
        size = Path("FileConverter.icns").stat().st_size
        print(f"   大小: {size} bytes")
    else:
        print(f"❌ 转换失败: {result.stderr.decode()}")

    # 清理 iconset
    subprocess.run(['rm', '-rf', str(iconset)])

if __name__ == '__main__':
    main()
