import sys
import argparse
from pathlib import Path
from PIL import Image, ImageOps

def convert_for_oasis_fixed(input_path, output_path, target_size=(1264, 1680)):
    try:
        with Image.open(input_path) as img:
            print(f"处理中: {input_path} | Mode: {img.mode}")

            # 1. 强制转为 RGB
            # 即使原图是黑白，也必须转 RGB，否则 quantize 映射会出错导致全黑
            if img.mode != 'RGB':
                img = img.convert('RGB')

            # 2. Resize (Lanczos)
            img_fitted = ImageOps.fit(
                img, 
                target_size, 
                method=Image.Resampling.LANCZOS, 
                centering=(0.5, 0.5)
            )

            # 3. 核心修正：构建 16 色 RGB 调色板
            # Kindle 虽然是灰度屏，但逻辑上是 16 个特定的亮度值
            palette_img = Image.new('P', (1, 1))
            
            # 生成标准的 16 级灰度 RGB 列表 [0,0,0, 17,17,17, ... 255,255,255]
            palette_data = []
            for i in range(16):
                val = int(i * 255 / 15)
                palette_data.extend((val, val, val))
            
            # 补齐 256 色 (768个值)，否则 Pillow 会报错
            palette_data.extend([0] * (768 - len(palette_data)))
            palette_img.putpalette(palette_data)

            # 4. 量化 + 抖动 (Quantize with Floyd-Steinberg)
            # 关键点：输入是 RGB，调色板也是 RGB 定义的，这样计算欧氏距离才准确
            img_dithered_p = img_fitted.quantize(
                palette=palette_img, 
                dither=Image.Dither.FLOYDSTEINBERG
            )

            # 5. 转回 'L' 模式保存
            # quantize 得到的是 'P' (索引) 模式。
            # 为了兼容性（防止某些看图软件读不出 Palette 导致全黑），
            # 同时也为了 Kindle 渲染稳定，我们将索引值转换回实际的灰度像素值。
            final_img = img_dithered_p.convert('L')

            # 6. 保存
            final_img.save(output_path, "PNG", optimize=True)
            print(f"✅ 完成: {output_path}")

    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Kindle Oasis 2 Fixed (RGB->Quantize->L)")
    parser.add_argument("input", help="输入图片路径")
    parser.add_argument("-o", "--output", help="输出图片路径 (可选)")
    
    args = parser.parse_args()
    input_p = Path(args.input)
    
    if not input_p.exists():
        sys.exit("找不到文件")

    if args.output:
        output_p = Path(args.output)
    else:
        output_p = input_p.with_name(f"{input_p.stem}_k_fixed.png")

    convert_for_oasis_fixed(input_p, output_p)