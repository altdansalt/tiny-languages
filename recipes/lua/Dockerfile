# lua — canonical tiny language, pure C, no deps
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git readline-dev
WORKDIR /src
RUN git clone --depth 1 https://github.com/lua/lua .
RUN make -j"$(nproc)"
# smoke test: build fails loudly if the interpreter can't run
RUN printf 'print("ok " .. _VERSION)\n' > /smoke.lua \
    && ./lua /smoke.lua | tee /smoke.out \
    && grep -q '^ok Lua' /smoke.out
RUN printf 'BINSIZE %s %s\n' "$(stat -c %s ./lua)" "lua"
CMD ["/src/lua", "/smoke.lua"]
