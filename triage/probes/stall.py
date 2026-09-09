# A tiny FUSE file system (libfuse3 through ctypes) whose big.bin stops answering reads after
# its first 64 KB, as a network share that stopped answering does. Used by a probe only.
import ctypes
import errno
import stat
import sys
import threading
import time

lib = ctypes.CDLL("libfuse3.so.3")

class Timespec(ctypes.Structure):
    _fields_ = [("tv_sec", ctypes.c_long), ("tv_nsec", ctypes.c_long)]

class Stat(ctypes.Structure):  # x86_64 struct stat
    _fields_ = [
        ("st_dev", ctypes.c_ulong), ("st_ino", ctypes.c_ulong), ("st_nlink", ctypes.c_ulong),
        ("st_mode", ctypes.c_uint), ("st_uid", ctypes.c_uint), ("st_gid", ctypes.c_uint),
        ("pad0", ctypes.c_int), ("st_rdev", ctypes.c_ulong), ("st_size", ctypes.c_long),
        ("st_blksize", ctypes.c_long), ("st_blocks", ctypes.c_long),
        ("st_atim", Timespec), ("st_mtim", Timespec), ("st_ctim", Timespec),
        ("reserved", ctypes.c_long * 3),
    ]

GETATTR = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.POINTER(Stat), ctypes.c_void_p)
FILLER = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(Stat), ctypes.c_long, ctypes.c_int)
READDIR = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p, FILLER, ctypes.c_long, ctypes.c_void_p, ctypes.c_int)
OPEN = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p)
READ = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char), ctypes.c_size_t, ctypes.c_long, ctypes.c_void_p)

FILES = {b"/a.txt": b"a\n", b"/big.bin": 10 * 1024 * 1024}
MARKER = "/tmp/fuse-stalled"
never = threading.Event()
now = int(time.time())

def size_of(path):
    v = FILES[path]
    return len(v) if isinstance(v, bytes) else v

def getattr_(path, st, fi):
    ctypes.memset(st, 0, ctypes.sizeof(Stat))
    s = st.contents
    s.st_mtim.tv_sec = s.st_atim.tv_sec = s.st_ctim.tv_sec = now
    if path == b"/":
        s.st_mode = stat.S_IFDIR | 0o755
        s.st_nlink = 2
        return 0
    if path in FILES:
        s.st_mode = stat.S_IFREG | 0o644
        s.st_nlink = 1
        s.st_size = size_of(path)
        return 0
    return -errno.ENOENT

def readdir_(path, buf, filler, offset, fi, flags):
    if path != b"/":
        return -errno.ENOENT
    for name in (b".", b"..", b"a.txt", b"big.bin"):
        filler(buf, name, None, 0, 0)
    return 0

def open_(path, fi):
    return 0 if path in FILES else -errno.ENOENT

def read_(path, buf, size, offset, fi):
    if path not in FILES:
        return -errno.ENOENT
    v = FILES[path]
    if isinstance(v, bytes):
        data = v[offset:offset + size]
        ctypes.memmove(buf, data, len(data))
        return len(data)
    if offset >= 64 * 1024:
        open(MARKER, "w").close()
        sys.stderr.write(f"read at {offset} is stuck\n")
        never.wait()
    n = max(0, min(size, v - offset))
    ctypes.memset(buf, 0x41, n)
    return n

callbacks = [GETATTR(getattr_), READDIR(readdir_), OPEN(open_), READ(read_)]
ops = (ctypes.c_void_p * 42)()
ops[0] = ctypes.cast(callbacks[0], ctypes.c_void_p)   # getattr
ops[12] = ctypes.cast(callbacks[2], ctypes.c_void_p)  # open
ops[13] = ctypes.cast(callbacks[3], ctypes.c_void_p)  # read
ops[24] = ctypes.cast(callbacks[1], ctypes.c_void_p)  # readdir

args = [b"stall", b"-f", sys.argv[1].encode()]
argv = (ctypes.c_char_p * len(args))(*args)
sys.exit(lib.fuse_main_real(len(args), argv, ops, ctypes.sizeof(ops), None))
