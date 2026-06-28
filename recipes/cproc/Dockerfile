# cproc — small C11 compiler frontend on the QBE backend (a complete tiny C
# toolchain: frontend + SSA backend, needing only an assembler+linker + libc).
# Native arm64: QBE supports aarch64; binutils provides as/ld.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git binutils musl-dev
WORKDIR /src
# Use the live UPSTREAM QBE mirror: current cproc emits the `extern` linkage IR
# keyword, which only recent upstream QBE parses. The 8l/qbe and michaelforney/qbe
# GitHub mirrors lag (no `extern`) — and 8l/qbe also has a "$define" typo on its
# aarch64 Makefile branch. omenos/mirror-qbe tracks c9x.me and has both fixed.
# newer upstream qbe links the binary to ./qbe (repo root), not obj/qbe
RUN git clone --depth 1 https://github.com/omenos/mirror-qbe qbe \
    && make -C qbe -j"$(nproc)" \
    && cp qbe/qbe /usr/local/bin/qbe
RUN git clone --depth 1 https://github.com/michaelforney/cproc cproc \
    && cd cproc && ./configure --with-qbe=/usr/local/bin/qbe && make -j"$(nproc)" \
    && cp cproc cproc-qbe /usr/local/bin/    # driver spawns cproc-qbe alongside it
# smoke: cproc compiles a hello world end-to-end (cproc -> qbe -> as -> ld)
RUN printf '#include <stdio.h>\nint main(){printf("ok-cproc\\n");return 0;}\n' > /smoke.c \
    && cproc -o /smoke /smoke.c && /smoke | tee /smoke.out \
    && grep -q '^ok-cproc' /smoke.out
RUN printf 'BINSIZE %s cproc\n' "$(stat -c %s /usr/local/bin/cproc)"
CMD ["sh", "-c", "cproc -o /t /smoke.c && /t"]
