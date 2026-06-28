# ape — Ape language: single-file amalgamation (ape.c/ape.h) + CLI in examples/
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/kgabis/ape .
RUN cd examples && make ape
RUN BIN=$(find . -type f -name ape -perm -u+x | head -1) && cp "$BIN" /usr/local/bin/ape
RUN printf 'println("ok-ape")\n' > /smoke.ape \
    && ape /smoke.ape | tee /smoke.out && grep -q '^ok-ape' /smoke.out
RUN printf 'BINSIZE %s ape\n' "$(stat -c %s /usr/local/bin/ape)"
CMD ["ape", "/smoke.ape"]
