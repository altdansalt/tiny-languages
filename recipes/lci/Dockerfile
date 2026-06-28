# lci — LOLCODE interpreter in C (cmake)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cmake readline-dev ncurses-dev
WORKDIR /src
RUN git clone --depth 1 https://github.com/justinmeza/lci .
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)"
RUN BIN=$(find build . -maxdepth 2 -type f -name lci -perm -u+x | head -1) \
    && cp "$BIN" /usr/local/bin/lci
RUN printf 'HAI 1.4\nVISIBLE "ok-lci"\nKTHXBYE\n' > /smoke.lol \
    && lci /smoke.lol | tee /smoke.out && grep -q '^ok-lci' /smoke.out
RUN printf 'BINSIZE %s lci\n' "$(stat -c %s /usr/local/bin/lci)"
CMD ["lci", "/smoke.lol"]
