# brainfuck — feature-rich Brainfuck interpreter by fabianishere (cmake)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cmake
WORKDIR /src
RUN git clone --depth 1 https://github.com/fabianishere/brainfuck .
RUN cmake -B build -DENABLE_CLI=ON -DENABLE_EDITLINE=OFF -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)"
RUN BIN=$(find build -type f -name brainfuck -perm -u+x | head -1) \
    && cp "$BIN" /usr/local/bin/brainfuck
# run a committed hello-world program
RUN SAMPLE=$(find . -name 'hello*.bf' | head -1) && echo "using $SAMPLE" \
    && brainfuck "$SAMPLE" | tee /smoke.out && grep -qi 'hello' /smoke.out
RUN printf 'BINSIZE %s brainfuck\n' "$(stat -c %s /usr/local/bin/brainfuck)"
CMD ["sh", "-c", "brainfuck $(find /src -name 'hello*.bf' | head -1)"]
