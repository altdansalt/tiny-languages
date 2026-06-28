# gravity — dynamically typed embeddable language (game scripting)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/marcobambini/gravity .
RUN make -j"$(nproc)"
RUN BIN=$(find . -maxdepth 2 -type f -name gravity -perm -u+x | head -1) \
    && cp "$BIN" /usr/local/bin/gravity
RUN printf 'func main() { System.print("ok-gravity"); }\n' > /smoke.gravity \
    && gravity /smoke.gravity | tee /smoke.out && grep -q '^ok-gravity' /smoke.out
RUN printf 'BINSIZE %s gravity\n' "$(stat -c %s /usr/local/bin/gravity)"
CMD ["gravity", "/smoke.gravity"]

