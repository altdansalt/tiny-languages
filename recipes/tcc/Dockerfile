# tcc — Tiny C Compiler. The musl build trips over a wchar_t redefinition while
# compiling its runtime lib (bcheck.o); on a glibc base it builds cleanly.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 https://github.com/TinyCC/tinycc.git .
RUN ./configure && make -j"$(nproc)" && make install
# tcc compiles AND runs a hello world via its built-in runner (needs its
# installed include dir + libtcc1.a, hence `make install`)
RUN printf '#include <stdio.h>\nint main(){printf("ok-tcc\\n");return 0;}\n' > /smoke.c \
    && tcc -run /smoke.c | tee /smoke.out && grep -q '^ok-tcc' /smoke.out
RUN printf 'BINSIZE %s tcc\n' "$(stat -c %s "$(command -v tcc)")"
CMD ["tcc", "-run", "/smoke.c"]
