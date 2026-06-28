# quickjs-ng — maintained fork of Bellard's QuickJS (small JS engine)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cmake
WORKDIR /src
RUN git clone --depth 1 https://github.com/quickjs-ng/quickjs .
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)"
RUN BIN=$(find build -type f -name qjs -perm -u+x | head -1) && cp "$BIN" /usr/local/bin/qjs
RUN qjs -e 'print("ok-qjs")' | tee /smoke.out && grep -q '^ok-qjs' /smoke.out
RUN printf 'BINSIZE %s qjs\n' "$(stat -c %s /usr/local/bin/qjs)"
CMD ["qjs", "-e", "print(\"ok-qjs\")"]
