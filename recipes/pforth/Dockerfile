# pforth — portable Forth in C. Standalone variant embeds the dictionary.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cmake
WORKDIR /src
RUN git clone --depth 1 https://github.com/philburk/pforth .
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)"
# the standalone binary lands in fth/, not under build/
RUN BIN=$(find . -type f -name 'pforth_standalone' -perm -u+x | head -1) \
    && cp "$BIN" /usr/local/bin/pforth
RUN printf ': t 42 . ;  t\nbye\n' | pforth | tee /smoke.out && grep -q '42' /smoke.out
RUN printf 'BINSIZE %s pforth\n' "$(stat -c %s /usr/local/bin/pforth)"
CMD ["sh", "-c", "printf ': t 42 . ;  t\\nbye\\n' | pforth"]
