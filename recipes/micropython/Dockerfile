# micropython — Python for microcontrollers; the unix port builds a CLI.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache python3 pkgconf libffi-dev
WORKDIR /src
RUN git clone --depth 1 https://github.com/micropython/micropython .
RUN make -C mpy-cross -j"$(nproc)" || true
# The "standard" variant pulls berkeley-db, which needs sys/cdefs.h (absent on
# musl). The "minimal" variant is self-contained and truer to "tiny".
RUN make -C ports/unix VARIANT=minimal -j"$(nproc)"
RUN BIN=$(find ports/unix -type f -name micropython -perm -u+x | head -1) \
    && cp "$BIN" /usr/local/bin/micropython
RUN micropython -c 'print("ok-mpy")' | tee /smoke.out && grep -q '^ok-mpy' /smoke.out
RUN printf 'BINSIZE %s micropython\n' "$(stat -c %s /usr/local/bin/micropython)"
CMD ["micropython", "-c", "print(\"ok-mpy\")"]
