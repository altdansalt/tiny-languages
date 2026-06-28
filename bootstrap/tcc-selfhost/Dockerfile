# Bootstrap probe: tcc self-hosting.
# Stage 1: build tcc with the system C compiler (gcc).
# Stage 2: rebuild tcc *using the stage-1 tcc as the compiler*.
# Then prove the stage-2 tcc (a tcc built by tcc) can compile and run a program.
# This demonstrates the self-hosting edge: a C compiler that reproduces itself.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 https://github.com/TinyCC/tinycc .
# stage 1 — tcc compiled by gcc
RUN ./configure && make -j"$(nproc)" && make install \
    && cp tcc /tcc-stage1 && tcc --version
# stage 2 — tcc compiled by the stage-1 tcc
RUN make clean \
    && ./configure --cc=/tcc-stage1 \
    && make -j"$(nproc)" \
    && cp tcc /tcc-stage2
# proof: the tcc-built tcc compiles and runs a hello world
RUN printf '#include <stdio.h>\nint main(){printf("ok-selfhost\\n");return 0;}\n' > /h.c \
    && /tcc-stage2 -run /h.c | tee /smoke.out && grep -q '^ok-selfhost' /smoke.out
RUN printf 'BINSIZE %s tcc-stage2\n' "$(stat -c %s /tcc-stage2)"
CMD ["/tcc-stage2", "-run", "/h.c"]
