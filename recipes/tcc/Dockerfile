# tcc — Tiny C Compiler. Targets native arch (arm64 here), one-pass codegen.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://repo.or.cz/tinycc.git .
RUN ./configure --config-musl && make -j"$(nproc)"
# smoke: tcc compiles AND runs a hello world via its built-in runner
RUN printf '#include <stdio.h>\nint main(){printf("ok-tcc\\n");return 0;}\n' > /smoke.c \
    && ./tcc -run /smoke.c | tee /smoke.out \
    && grep -q '^ok-tcc' /smoke.out
RUN printf 'BINSIZE %s tcc\n' "$(stat -c %s tcc)"
CMD ["/src/tcc", "-run", "/smoke.c"]
