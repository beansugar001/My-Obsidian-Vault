import sys
src, dst = sys.argv[1], sys.argv[2]
data = open(src, 'rb').read()
WORD = 4
MAXW = 128
words = []
for i in range(0, len(data), WORD):
    chunk = data[i:i+WORD].ljust(WORD, b'\x00')
    words.append(int.from_bytes(chunk, 'little'))
if len(words) > MAXW:
    raise SystemExit('firmware too large: %d words > %d' % (len(words), MAXW))
words.extend([0x00000013] * (MAXW - len(words)))
with open(dst, 'w') as f:
    for w in words:
        f.write('%08x\n' % w)
print('bytes=%d words=%d' % (len(data), len([1 for i in range(0, len(data), WORD)])))
