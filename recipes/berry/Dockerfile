# berry — ultra-low-footprint scripting for microcontrollers
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cmake python3
WORKDIR /src
RUN git clone --depth 1 https://github.com/berry-lang/berry .
# readline is optional; leave it off to keep the binary dependency-free
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DUSE_READLINE_LIB=0 \
    && cmake --build build -j"$(nproc)"
RUN BIN=$(find build -type f -name berry -perm -u+x | head -1) \
    && cp "$BIN" /usr/local/bin/berry
RUN printf "print('ok-berry')\n" > /smoke.be \
    && berry /smoke.be | tee /smoke.out && grep -q '^ok-berry' /smoke.out
RUN printf 'BINSIZE %s berry\n' "$(stat -c %s /usr/local/bin/berry)"
CMD ["berry", "/smoke.be"]
