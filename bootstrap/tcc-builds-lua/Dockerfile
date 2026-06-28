# Bootstrap probe: a tiny C compiler building a tiny language.
# Build tcc (with gcc), then use *tcc* to compile Lua from source, and run it.
# Demonstrates a real bootstrap edge: tcc -> lua (gcc only seeds tcc).
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 https://github.com/TinyCC/tinycc tcc \
    && cd tcc && ./configure && make -j"$(nproc)" && make install
# compile lua using tcc as the C compiler (CC=tcc)
RUN git clone --depth 1 https://github.com/lua/lua lua \
    && make -C lua CC=tcc -j"$(nproc)"
RUN printf 'print("ok-tcc-built-lua " .. _VERSION)\n' > /smoke.lua \
    && /src/lua/lua /smoke.lua | tee /smoke.out && grep -q '^ok-tcc-built-lua' /smoke.out
RUN printf 'BINSIZE %s lua\n' "$(stat -c %s /src/lua/lua)"
CMD ["/src/lua/lua", "/smoke.lua"]
