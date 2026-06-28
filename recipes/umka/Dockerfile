# umka — statically typed embeddable scripting language
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/vtereshkov/umka-lang .
# Makefile hardcodes -malign-double (x86-only); strip it for arm64.
RUN sed -i 's/-malign-double//g' Makefile
RUN make -j"$(nproc)"
RUN BIN=$(find . -type f -name umka -perm -u+x | head -1) && cp "$BIN" /usr/local/bin/umka
RUN printf 'fn main() { printf("ok-umka\\n") }\n' > /smoke.um \
    && umka /smoke.um | tee /smoke.out && grep -q '^ok-umka' /smoke.out
RUN printf 'BINSIZE %s umka\n' "$(stat -c %s /usr/local/bin/umka)"
CMD ["umka", "/smoke.um"]
