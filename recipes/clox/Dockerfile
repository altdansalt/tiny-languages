# clox — bytecode VM for Lox from "Crafting Interpreters"
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/munificent/craftinginterpreters .
RUN make clox
RUN printf 'print 1 + 2;\n' > /smoke.lox \
    && ./clox /smoke.lox | tee /smoke.out && grep -q '^3$' /smoke.out
RUN printf 'BINSIZE %s clox\n' "$(stat -c %s ./clox)"
CMD ["/src/clox", "/smoke.lox"]
