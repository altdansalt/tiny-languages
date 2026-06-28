# mac — minimal bytecode VM in C (felixangell). Runs a hardcoded program (5+6).
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/felixangell/mac .
RUN make
RUN BIN=$(find . -maxdepth 2 -type f -name mac -perm -u+x | head -1) \
    && cp "$BIN" /usr/local/bin/mac
RUN mac | tee /smoke.out && grep -qi 'done\|popped' /smoke.out
RUN printf 'BINSIZE %s mac\n' "$(stat -c %s /usr/local/bin/mac)"
CMD ["mac"]
