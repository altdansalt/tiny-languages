# Bootstrap probe (Tier 0, whole-system): build a Linux kernel from source and
# BOOT it. PATHS.md #3 — the one artifact the tiny compilers can't build (a modern
# kernel needs GCC + extensions), so this keeps GCC on the critical path while
# closing the bottom of the stack: from-source aarch64 Image -> booted to userspace.
#
# Native aarch64 compile (no emulation for the build). The boot is qemu-system-
# aarch64 in TCG (no nested KVM in a container) running the freshly built Image
# with a BusyBox initramfs, all the way to a userspace process that prints a marker
# and powers the machine off (so qemu exits and the RUN can assert success).
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc make bc bison flex libssl-dev libelf-dev \
        curl xz-utils ca-certificates cpio gzip busybox-static \
        qemu-system-arm \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
ARG KVER=6.6.52
RUN curl -fsSL "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz" \
        | tar xJ --strip-components=1
# from-source kernel: arm64 defconfig (reliable PL011 console + initramfs support)
RUN make ARCH=arm64 defconfig \
    && make ARCH=arm64 -j"$(nproc)" Image \
    && ls -l arch/arm64/boot/Image
# a minimal userspace: one static BusyBox + an init that proves we reached ring 3
RUN mkdir -p /ir/bin /ir/proc /ir/sys /ir/dev \
    && cp /bin/busybox /ir/bin/busybox \
    && ln -s busybox /ir/bin/sh \
    && printf '#!/bin/sh\n\
/bin/busybox mount -t proc none /proc 2>/dev/null\n\
echo "tiny-kernel-userspace-ok arch=$(/bin/busybox uname -m) kver=$(/bin/busybox uname -r)"\n\
/bin/busybox poweroff -f\n' > /ir/init \
    && chmod +x /ir/init \
    && ( cd /ir && find . | cpio -o -H newc 2>/dev/null | gzip > /initramfs.cpio.gz ) \
    && ls -l /initramfs.cpio.gz
# boot the from-source kernel under qemu, into our init, and assert it reached
# userspace. init powers off -> qemu exits 0; timeout guards a hang.
RUN timeout 300 qemu-system-aarch64 -M virt -cpu cortex-a57 -smp 2 -m 512 \
        -nographic -no-reboot -nic none \
        -kernel arch/arm64/boot/Image -initrd /initramfs.cpio.gz \
        -append "console=ttyAMA0 panic=-1 rdinit=/init" 2>&1 | tee /boot.log; \
    grep -q 'tiny-kernel-userspace-ok' /boot.log \
        && echo "from-source kernel booted to userspace"
RUN { echo "Linux ${KVER} aarch64, built from source"; \
      grep -m1 'tiny-kernel-userspace-ok' /boot.log; } > /done
RUN printf 'BINSIZE %s Image\n' "$(stat -c %s arch/arm64/boot/Image)"
CMD ["cat", "/done"]
