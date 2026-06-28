# Bootstrap probe (Tier 3): build a libc from source.
# Build musl from the upstream release tarball, then use musl's musl-gcc wrapper
# to compile+run a program against the freshly built libc.
# NOTE: built on a glibc base (debian) on purpose — musl only generates its
# gcc wrapper on a non-musl host (its job is to redirect a glibc gcc to musl).
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN wget -q https://musl.libc.org/releases/musl-1.2.5.tar.gz \
    && tar xf musl-1.2.5.tar.gz
WORKDIR /src/musl-1.2.5
RUN ./configure --prefix=/opt/musl && make -j"$(nproc)" && make install
# proof: glibc's gcc, redirected by musl-gcc, builds a binary against from-source musl
RUN printf '#include <stdio.h>\nint main(){printf("ok-musl\\n");return 0;}\n' > /h.c \
    && /opt/musl/bin/musl-gcc /h.c -o /h \
    && /h | tee /smoke.out && grep -q '^ok-musl' /smoke.out
# informational: show the binary's interpreter — for a musl dynamic binary built
# from /opt/musl this is /opt/musl/lib/libc.so (in musl the loader *is* libc).
# (glibc's ldd can't introspect a musl binary, so we don't gate on it.)
RUN echo "interpreter of the musl-built binary:" \
    && readelf -l /h | grep -i 'interpreter' || true
RUN printf 'BINSIZE %s libc.so\n' "$(stat -c %s /opt/musl/lib/libc.so)"
CMD ["/h"]
