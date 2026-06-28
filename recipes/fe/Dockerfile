# fe — ~800 LOC Lisp by rxi. Single source; main() under -DFE_STANDALONE.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/rxi/fe .
RUN cc -O2 -DFE_STANDALONE src/fe.c -o fe
# file input runs the script without REPL prompts/echo
RUN printf '(print "ok-fe")\n' > /smoke.fe \
    && ./fe /smoke.fe | tee /smoke.out && grep -q 'ok-fe' /smoke.out
RUN printf 'BINSIZE %s fe\n' "$(stat -c %s ./fe)"
CMD ["/src/fe", "/smoke.fe"]
