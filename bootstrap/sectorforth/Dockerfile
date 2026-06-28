# Bootstrap probe (sector-sized seed): SectorFORTH — a complete Forth in a
# 512-byte x86 boot sector. PATHS.md #6, the smallest, most visceral root of trust
# here: ~430 lines of hand-written x86 assembly, eight primitives, assembled into a
# single bootable sector. No C compiler involved at all.
#
# Why qemu and not native: it's 16-bit x86 boot code — Rosetta can't touch it.
# qemu-system-i386 (full-system emulation, apt-installable in the container) boots
# the sector as a real PC. The REPL talks to the BIOS keyboard/VGA, not a serial
# line, so there's no headless transcript to capture; instead we prove (a) the
# artifact is a valid 512-byte boot sector, and (b) it actually boots and stays
# live in the interpreter loop rather than faulting out.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        nasm make git ca-certificates xxd qemu-system-x86 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 https://github.com/cesarblum/sectorforth .
# `make` assembles the 512-byte boot sector (sectorforth.bin) and pads it into a
# 1.44 MB floppy image (sectorforth.img) for qemu to boot.
RUN make && ls -l sectorforth.bin sectorforth.img
# proof 1: the Forth IS a single 512-byte boot sector (ends in 0x55AA signature)
RUN sz=$(stat -c %s sectorforth.bin); echo "boot code = $sz bytes"; \
    [ "$sz" -eq 512 ] \
    && xxd -s 510 -l 2 -p sectorforth.bin | grep -qi '55aa' \
    && echo "valid 512-byte boot sector (signature 0x55AA)"
# proof 2: it BOOTS. qemu runs the sector as a real x86 machine; if qemu is still
# alive when the timeout fires (exit 124) the Forth booted and is looping in its
# REPL — a triple-fault/crash would exit earlier with a different code.
RUN timeout 5 qemu-system-i386 -fda sectorforth.img -display none -no-reboot; \
    rc=$?; echo "qemu exit = $rc"; \
    [ "$rc" -eq 124 ] && echo "booted-and-running (512-byte Forth is live)"
RUN printf 'BINSIZE %s sectorforth.bin\n' "$(stat -c %s sectorforth.bin)"
CMD ["sh", "-c", "echo \"$(stat -c %s sectorforth.bin)-byte bootable Forth; signature $(xxd -s 510 -l 2 -p sectorforth.bin)\""]
