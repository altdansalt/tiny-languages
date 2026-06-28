# pocketlang — small, fast, embeddable scripting language
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/ThakeeNathees/pocketlang .
RUN make -j"$(nproc)"
RUN BIN=$(find build bin . -maxdepth 3 -type f -name pocket -perm -u+x 2>/dev/null | head -1) \
    && cp "$BIN" /usr/local/bin/pocket
RUN printf 'print("ok-pocket")\n' > /smoke.pk \
    && pocket /smoke.pk | tee /smoke.out && grep -q '^ok-pocket' /smoke.out
RUN printf 'BINSIZE %s pocket\n' "$(stat -c %s /usr/local/bin/pocket)"
CMD ["pocket", "/smoke.pk"]
