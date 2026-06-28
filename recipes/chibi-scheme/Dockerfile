# chibi-scheme — small R7RS Scheme. Install to a prefix so it finds its modules.
# (Running uninstalled with SEXP_USE_DL=0 mis-loads binaries as Scheme: "undefined variable |ELF".)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/ashinn/chibi-scheme .
RUN make -j"$(nproc)" && make PREFIX=/usr/local install
# Use -e (not stdin) so we don't land in the REPL and prefix output with prompts.
RUN LD_LIBRARY_PATH=/usr/local/lib chibi-scheme -e '(begin (display "ok-chibi") (newline))' \
    | tee /smoke.out && grep -q '^ok-chibi' /smoke.out
RUN printf 'BINSIZE %s chibi-scheme\n' "$(stat -c %s "$(command -v chibi-scheme)")"
CMD ["sh", "-c", "LD_LIBRARY_PATH=/usr/local/lib chibi-scheme -e '(begin (display \"ok-chibi\") (newline))'"]
