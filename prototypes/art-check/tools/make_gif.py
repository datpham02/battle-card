"""Crop a region from a sequence of PNG screenshots and write a looping GIF (pure Python).

usage: make_gif.py OUT.gif X0 Y0 X1 Y1 DELAY_CS|@delays.json SCALE IN1.png IN2.png ...
Also writes OUT.strip.png with the frames side by side (1 px gap).
"""
import struct, sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import read_png, write_png


def lzw_encode(indices, min_code_size):
    clear = 1 << min_code_size
    eoi = clear + 1
    out_bits = []  # list of (code, size)
    dict_ = {(i,): i for i in range(clear)}
    next_code = eoi + 1
    code_size = min_code_size + 1
    out_bits.append((clear, code_size))
    w = ()
    for k in indices:
        wk = w + (k,)
        if wk in dict_:
            w = wk
        else:
            out_bits.append((dict_[w], code_size))
            if next_code < 4096:
                dict_[wk] = next_code
                next_code += 1
                if next_code - 1 == (1 << code_size) and code_size < 12:
                    code_size += 1
            else:
                out_bits.append((clear, code_size))
                dict_ = {(i,): i for i in range(clear)}
                next_code = eoi + 1
                code_size = min_code_size + 1
            w = (k,)
    if w:
        out_bits.append((dict_[w], code_size))
    out_bits.append((eoi, code_size))
    # pack bits LSB first
    data = bytearray()
    acc = 0
    nbits = 0
    for code, size in out_bits:
        acc |= code << nbits
        nbits += size
        while nbits >= 8:
            data.append(acc & 0xFF)
            acc >>= 8
            nbits -= 8
    if nbits:
        data.append(acc & 0xFF)
    return bytes(data)


def main():
    out = sys.argv[1]
    x0, y0, x1, y1 = map(int, sys.argv[2:6])
    delay_arg, scale = sys.argv[6], int(sys.argv[7])
    files = sys.argv[8:]
    # DELAY_CS is one number for every frame, or @file.json with a list of per-frame delays (cs)
    if delay_arg.startswith('@'):
        import json
        delays = [max(2, int(d)) for d in json.load(open(delay_arg[1:]))]
        assert len(delays) == len(files), f'{len(delays)} delays for {len(files)} frames'
    else:
        delays = [int(delay_arg)] * len(files)
    frames = []
    for f in files:
        w, h, px = read_png(f)
        crop = [[px[y][x][:3] for x in range(x0, x1)] for y in range(y0, y1)]
        if scale > 1:
            crop = [[c for c in row for _ in range(scale)] for row in crop for _ in range(scale)]
        frames.append(crop)
    W, H = len(frames[0][0]), len(frames[0])
    palette = []
    index = {}
    for fr in frames:
        for row in fr:
            for c in row:
                if c not in index:
                    index[c] = len(palette)
                    palette.append(c)
    assert len(palette) <= 256, f'{len(palette)} colours'
    bits = max(1, (len(palette) - 1).bit_length())
    size = 1 << bits
    gif = bytearray(b'GIF89a')
    gif += struct.pack('<HHBBB', W, H, 0x80 | ((bits - 1) << 4) | (bits - 1), 0, 0)
    for i in range(size):
        gif += bytes(palette[i] if i < len(palette) else (0, 0, 0))
    gif += b'\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00'  # loop forever
    for fi, fr in enumerate(frames):
        gif += b'\x21\xF9\x04\x00' + struct.pack('<H', delays[fi]) + b'\x00\x00'
        gif += b'\x2C' + struct.pack('<HHHHB', 0, 0, W, H, 0)
        min_code = max(2, bits)
        gif.append(min_code)
        data = lzw_encode([index[c] for row in fr for c in row], min_code)
        for i in range(0, len(data), 255):
            chunk = data[i:i + 255]
            gif.append(len(chunk))
            gif += chunk
        gif.append(0)
    gif += b'\x3B'
    open(out, 'wb').write(gif)
    # strip
    gap = 2
    SW = W * len(frames) + gap * (len(frames) - 1)
    strip = []
    for y in range(H):
        row = []
        for i, fr in enumerate(frames):
            row.extend([(c[0], c[1], c[2], 255) for c in fr[y]])
            if i < len(frames) - 1:
                row.extend([(27, 23, 34, 255)] * gap)
        strip.append(row)
    write_png(out.rsplit('.', 1)[0] + '.strip.png', SW, H, strip)
    print(f'{out}: {len(frames)} frames {W}x{H}, {len(palette)} colours')


if __name__ == '__main__':
    main()
