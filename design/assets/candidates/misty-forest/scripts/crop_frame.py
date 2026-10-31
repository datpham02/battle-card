"""Crop/shift an RGBA PNG onto a new canvas without Pillow.

usage: crop_frame.py IN.png OUT.png NEW_W NEW_H DX DY
new_pixel(x, y) = old_pixel(x - DX, y - DY); outside = transparent.
Prints the bbox of the result and the set of alpha values.
"""
import struct, sys, zlib


def read_png(path):
    b = open(path, 'rb').read()
    assert b[:8] == b'\x89PNG\r\n\x1a\n'
    pos = 8
    idat = b''
    plte = None
    trns = None
    while pos < len(b):
        L, = struct.unpack('>I', b[pos:pos + 4])
        t = b[pos + 4:pos + 8]
        d = b[pos + 8:pos + 8 + L]
        pos += 12 + L
        if t == b'IHDR':
            w, h, bd, ct, _, _, il = struct.unpack('>IIBBBBB', d)
            assert bd == 8 and il == 0, 'only 8-bit non-interlaced'
        elif t == b'PLTE':
            plte = d
        elif t == b'tRNS':
            trns = d
        elif t == b'IDAT':
            idat += d
    bpp = {6: 4, 2: 3, 3: 1, 0: 1, 4: 2}[ct]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    i = 0
    for y in range(h):
        f = raw[i]
        i += 1
        cur = bytearray(raw[i:i + stride])
        i += stride
        for x in range(stride):
            a = cur[x - bpp] if x >= bpp else 0
            bb = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                cur[x] = (cur[x] + a) & 255
            elif f == 2:
                cur[x] = (cur[x] + bb) & 255
            elif f == 3:
                cur[x] = (cur[x] + (a + bb) // 2) & 255
            elif f == 4:
                p = a + bb - c
                pa, pb, pc = abs(p - a), abs(p - bb), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (bb if pb <= pc else c)
                cur[x] = (cur[x] + pr) & 255
        rows.append(bytes(cur))
        prev = cur
    # expand to RGBA tuples
    px = []
    for r in rows:
        line = []
        for x in range(w):
            if ct == 6:
                line.append(tuple(r[x * 4:x * 4 + 4]))
            elif ct == 2:
                line.append(tuple(r[x * 3:x * 3 + 3]) + (255,))
            elif ct == 3:
                idx = r[x]
                a = trns[idx] if trns and idx < len(trns) else 255
                line.append(tuple(plte[idx * 3:idx * 3 + 3]) + (a,))
            elif ct == 0:
                line.append((r[x], r[x], r[x], 255))
            else:
                line.append((r[x * 2], r[x * 2], r[x * 2], r[x * 2 + 1]))
        px.append(line)
    return w, h, px


def write_png(path, w, h, px):
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    raw = b''.join(b'\x00' + b''.join(bytes(p) for p in row) for row in px)
    out = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(out)


def main():
    src, dst, nw, nh, dx, dy = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:7])
    w, h, px = read_png(src)
    out = []
    for y in range(nh):
        row = []
        for x in range(nw):
            ox, oy = x - dx, y - dy
            if 0 <= ox < w and 0 <= oy < h:
                p = px[oy][ox]
                row.append(p if p[3] else (0, 0, 0, 0))
            else:
                row.append((0, 0, 0, 0))
        out.append(row)
    # verify nothing opaque was cut off
    lost = sum(1 for y in range(h) for x in range(w)
               if px[y][x][3] and not (0 <= x + dx < nw and 0 <= y + dy < nh))
    xs = [x for y in range(nh) for x in range(nw) if out[y][x][3]]
    ys = [y for y in range(nh) for x in range(nw) if out[y][x][3]]
    alphas = sorted({out[y][x][3] for y in range(nh) for x in range(nw)})
    colours = {out[y][x][:3] for y in range(nh) for x in range(nw) if out[y][x][3]}
    write_png(dst, nw, nh, out)
    print(f'{dst}: {nw}x{nh} bbox x {min(xs)}-{max(xs)} (w {max(xs)-min(xs)+1}) '
          f'y {min(ys)}-{max(ys)} (h {max(ys)-min(ys)+1}) alphas {alphas} '
          f'colours {len(colours)} lost_opaque {lost}')


if __name__ == '__main__':
    main()
