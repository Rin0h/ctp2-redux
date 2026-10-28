"""List or compare the contents of Call to Power II .zfs packages.

    python tools/zfs.py list <file.zfs>
    python tools/zfs.py diff <a.zfs> <b.zfs>     # entries only in a/b, or different
    python tools/zfs.py extract <file.zfs> <name> <out>

Format (gs/fileio/prjfile.cpp): header with tag, version, record name length
and the first directory table; directory tables of 100 entries
(name, offset, number, size, time, flags) chained by an offset.
"""
import struct, sys, hashlib

def entries(path):
    with open(path, 'rb') as f:
        data = f.read()
    tag, version, namelen, per_table, count, key, head = struct.unpack_from('<4s6i', data, 0)
    out = {}
    entry = struct.Struct('<%ds5I' % namelen)
    while head:
        (head,) = struct.unpack_from('<i', data, head),
        head = head[0]
        break
    # walk again properly
    out = {}
    pos = struct.unpack_from('<4s6i', data, 0)[6]
    while pos:
        nxt = struct.unpack_from('<i', data, pos)[0]
        p = pos + 4
        for _ in range(per_table):
            name, offset, rnum, size, time, flags = entry.unpack_from(data, p)
            p += entry.size
            name = name.split(b'\0')[0].decode('latin-1').lower()
            if name and not (flags & 1):
                out[name] = (offset, size)
        pos = nxt
    return data, out

def main():
    cmd = sys.argv[1]
    if cmd == 'list':
        data, e = entries(sys.argv[2])
        for name, (off, size) in sorted(e.items()):
            print(f'{size:9d}  {name}')
    elif cmd == 'diff':
        da, a = entries(sys.argv[2])
        db, b = entries(sys.argv[3])
        for name in sorted(set(a) | set(b)):
            if name not in b:
                print('only in a:', name)
            elif name not in a:
                print('only in b:', name)
            else:
                ha = hashlib.md5(da[a[name][0]:a[name][0] + a[name][1]]).hexdigest()
                hb = hashlib.md5(db[b[name][0]:b[name][0] + b[name][1]]).hexdigest()
                if ha != hb:
                    print('different:', name)
    elif cmd == 'extract':
        data, e = entries(sys.argv[2])
        off, size = e[sys.argv[3].lower()]
        open(sys.argv[4], 'wb').write(data[off:off + size])

if __name__ == '__main__':
    main()
