# A tiny FUSE file system (libfuse3 through ctypes) that stops answering one kind of request,
# as a network share that stopped answering does. Used by probes only.
#   STALL_MODE=read      reads of big.bin after its first 64 KB
#   STALL_MODE=open      opening big.bin
#   STALL_MODE=getattr   getattr (stat) of big.bin, after the first STALL_AFTER calls (default 0)
#   STALL_MODE=listxattr listing the extended attributes of big.bin, after the first STALL_AFTER calls
#   STALL_MODE=readdir   listing the folder slow/
# Writes /tmp/fuse-stalled when a request gets stuck.
import ctypes
import errno
import os
import stat
import sys
import threading
import time

lib = ctypes.CDLL("libfuse3.so.3")
MODE = os.environ.get("STALL_MODE", "read")
STALL_AFTER = int(os.environ.get("STALL_AFTER", "0"))
MARKER = "/tmp/fuse-stalled"
never = threading.Event()
now = int(time.time())
getattr_calls = 0
lock = threading.Lock()

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
GETXATTR = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char), ctypes.c_size_t)
LISTXATTR = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_char_p, ctypes.POINTER(ctypes.c_char), ctypes.c_size_t)

FILES = {b"/a.txt": b"a\n", b"/big.bin": 10 * 1024 * 1024, b"/slow/c.txt": b"c\n"}
DIRS = {b"/": [b"a.txt", b"big.bin", b"slow"], b"/slow": [b"c.txt"]}

def stuck(what):
    open(MARKER, "w").close()
    sys.stderr.write(f"{what} is stuck\n")
    sys.stderr.flush()
    never.wait()

def size_of(path):
    v = FILES[path]
    return len(v) if isinstance(v, bytes) else v

def getattr_(path, st, fi):
    global getattr_calls
    if MODE == "getattr" and path == b"/big.bin":
        with lock:
            getattr_calls += 1
            n = getattr_calls
        if n > STALL_AFTER:
            stuck(f"getattr #{n} of big.bin")
    ctypes.memset(st, 0, ctypes.sizeof(Stat))
    s = st.contents
    s.st_mtim.tv_sec = s.st_atim.tv_sec = s.st_ctim.tv_sec = now
    if path in DIRS:
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
    if path not in DIRS:
        return -errno.ENOENT
    if MODE == "readdir" and path == b"/slow":
        stuck("readdir of slow/")
    for name in [b".", b".."] + DIRS[path]:
        filler(buf, name, None, 0, 0)
    return 0

def open_(path, fi):
    if path not in FILES:
        return -errno.ENOENT
    if MODE == "open" and path == b"/big.bin":
        stuck("open of big.bin")
    return 0

def read_(path, buf, size, offset, fi):
    if path not in FILES:
        return -errno.ENOENT
    v = FILES[path]
    if isinstance(v, bytes):
        data = v[offset:offset + size]
        ctypes.memmove(buf, data, len(data))
        return len(data)
    if MODE == "read" and offset >= 64 * 1024:
        stuck(f"read of big.bin at {offset}")
    n = max(0, min(size, v - offset))
    ctypes.memset(buf, 0x41, n)
    return n

def getxattr_(path, name, value, size):
    return -errno.ENODATA

listxattr_calls = 0

def listxattr_(path, lst, size):
    global listxattr_calls
    if MODE == "listxattr" and path == b"/big.bin":
        with lock:
            listxattr_calls += 1
            n = listxattr_calls
        if n > STALL_AFTER:
            stuck(f"listxattr #{n} of big.bin")
    return 0

callbacks = [GETATTR(getattr_), READDIR(readdir_), OPEN(open_), READ(read_), GETXATTR(getxattr_), LISTXATTR(listxattr_)]
ops = (ctypes.c_void_p * 42)()
ops[0] = ctypes.cast(callbacks[0], ctypes.c_void_p)   # getattr
ops[12] = ctypes.cast(callbacks[2], ctypes.c_void_p)  # open
ops[13] = ctypes.cast(callbacks[3], ctypes.c_void_p)  # read
ops[20] = ctypes.cast(callbacks[4], ctypes.c_void_p)  # getxattr
ops[21] = ctypes.cast(callbacks[5], ctypes.c_void_p)  # listxattr
ops[24] = ctypes.cast(callbacks[1], ctypes.c_void_p)  # readdir

# Attribute and entry caching off, so every stat reaches this file system
args = [b"stall", b"-f", b"-o", b"attr_timeout=0,entry_timeout=0,negative_timeout=0", sys.argv[1].encode()]
argv = (ctypes.c_char_p * len(args))(*args)
sys.exit(lib.fuse_main_real(len(args), argv, ops, ctypes.sizeof(ops), None))
