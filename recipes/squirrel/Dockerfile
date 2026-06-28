# squirrel — high-level OO scripting language (C++), tested on Raspberry Pi
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cmake
WORKDIR /src
RUN git clone --depth 1 https://github.com/albertodemichelis/squirrel .
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)"
RUN BIN=$(find build -type f -name sq -perm -u+x | head -1) && cp "$BIN" /usr/local/bin/sq
RUN printf 'print("ok-squirrel\\n")\n' > /smoke.nut \
    && sq /smoke.nut | tee /smoke.out && grep -q '^ok-squirrel' /smoke.out
RUN printf 'BINSIZE %s sq\n' "$(stat -c %s /usr/local/bin/sq)"
CMD ["sq", "/smoke.nut"]
