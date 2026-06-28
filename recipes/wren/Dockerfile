# wren — small class-based scripting VM. Built via its projects/make Makefiles.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/wren-lang/wren .
# The premake-generated makefiles hardcode -m64 (x86-only); strip it for arm64.
RUN sed -i 's/-m64//g; s/-m32//g' projects/make/*.make
# wren_test is the bundled CLI runner for .wren scripts
RUN make -C projects/make config=release_64bit wren_test -j"$(nproc)"
RUN printf 'System.print("ok-wren")\n' > /smoke.wren \
    && ./bin/wren_test /smoke.wren | tee /smoke.out \
    && grep -q '^ok-wren' /smoke.out
RUN printf 'BINSIZE %s wren_test\n' "$(stat -c %s bin/wren_test)"
CMD ["/src/bin/wren_test", "/smoke.wren"]
