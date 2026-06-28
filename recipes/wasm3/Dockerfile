# wasm3 — fast WebAssembly interpreter. Runs a committed test .wasm.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cmake
WORKDIR /src
RUN git clone --depth 1 https://github.com/wasm3/wasm3 .
# BUILD_WASI=none avoids the libuv/uvwasi dependency, which needs glibc-only
# kernel headers (linux/errqueue.h) absent on musl.
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_NATIVE=OFF -DBUILD_WASI=none \
    && cmake --build build -j"$(nproc)"
RUN BIN=$(find build -type f -name wasm3 -perm -u+x | head -1) && cp "$BIN" /usr/local/bin/wasm3
# fib32.wasm exports `fib`; fib(10)=55
# wasm3 prints the result to stderr, so merge it for the smoke capture
RUN wasm3 --func fib test/lang/fib32.wasm 10 2>&1 | tee /smoke.out && grep -q '55' /smoke.out
RUN printf 'BINSIZE %s wasm3\n' "$(stat -c %s /usr/local/bin/wasm3)"
CMD ["sh", "-c", "wasm3 --func fib /src/test/lang/fib32.wasm 10 2>&1"]
