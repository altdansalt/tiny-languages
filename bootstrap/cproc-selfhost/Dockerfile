# Bootstrap probe (self-hosting C compiler): cproc+QBE reproduces itself.
#
# PATHS.md #5. cproc is a small C11 front end emitting QBE SSA IR; QBE lowers it
# to native asm (aarch64 supported) and as+ld finish. The cleanest small "real"
# C compiler architecture here. This probe shows it SELF-HOSTING natively:
#   stage1: gcc builds cproc + qbe
#   stage2: that cproc rebuilds cproc (CC=cproc) — the compiler compiles itself
#   proof : the stage-2 cproc compiles+runs a program
# (qbe stays the backend throughout; the self-host claim is about the C front end
# recompiling its own C source.) See recipes/cproc for the qbe-mirror rationale.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git binutils musl-dev
WORKDIR /src
RUN git clone --depth 1 https://github.com/omenos/mirror-qbe qbe \
    && make -C qbe -j"$(nproc)" \
    && cp qbe/qbe /usr/local/bin/qbe
RUN git clone --depth 1 https://github.com/michaelforney/cproc cproc
# stage1: build cproc with the host C compiler (gcc)
RUN cd cproc && ./configure --with-qbe=/usr/local/bin/qbe && make -j"$(nproc)" \
    && cp cproc cproc-qbe /usr/local/bin/ \
    && cp cproc /usr/local/bin/cproc-stage1
# stage2: rebuild cproc USING cproc itself as the C compiler (self-host).
# Install the stage-2 driver AND its qbe helper together as cproc/cproc-qbe — the
# driver spawns "<argv0>-qbe" as a sibling, so the pair must travel together.
RUN cd cproc && make clean \
    && make CC=/usr/local/bin/cproc CFLAGS= -j"$(nproc)" \
    && cp cproc cproc-qbe /usr/local/bin/ \
    && echo "cproc rebuilt itself (the cproc now on PATH was compiled by cproc)" \
    && { cmp -s /usr/local/bin/cproc /usr/local/bin/cproc-stage1 \
         && echo "note: stage1/stage2 identical" \
         || echo "note: stage2 differs from gcc-built stage1 (expected)"; }
# proof: the cproc-built cproc compiles + runs a program end-to-end
RUN printf '#include <stdio.h>\nint main(){puts("cproc-selfhost-ok");return 0;}\n' > /smoke.c \
    && cproc -o /smoke /smoke.c && /smoke | tee /smoke.out \
    && grep -q '^cproc-selfhost-ok' /smoke.out
RUN printf 'BINSIZE %s cproc(stage2)\n' "$(stat -c %s /usr/local/bin/cproc)"
CMD ["sh", "-c", "cproc -o /t /smoke.c && /t"]
