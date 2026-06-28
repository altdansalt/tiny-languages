# femtolisp — small Scheme-like Lisp (used in early Julia bootstrap)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/JeffBezanson/femtolisp .
RUN make -j"$(nproc)"
RUN printf '(princ "ok-femto")(princ "\\n")\n' > /smoke.lsp \
    && ./flisp /smoke.lsp | tee /smoke.out \
    && grep -q '^ok-femto' /smoke.out
RUN printf 'BINSIZE %s flisp\n' "$(stat -c %s flisp)"
CMD ["/src/flisp", "/smoke.lsp"]
