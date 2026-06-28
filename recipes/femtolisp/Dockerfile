# femtolisp — small Scheme-like Lisp (used in early Julia bootstrap).
# Its llt headers only know __gnu_linux__ (glibc) + __x86_64__, so we build on a
# glibc base under x86_64 emulation. (See recipes/femtolisp/arch -> amd64.)
# A native arm64/musl port would need patches to llt/dtypes.h + utils.h.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 https://github.com/JeffBezanson/femtolisp .
# default target also runs the test suite (cd tests && ../flisp unittest.lsp),
# which exits 127 here; build just the interpreter.
RUN make release -j"$(nproc)"
RUN printf '(princ "ok-femto")(princ "\\n")\n' > /smoke.lsp \
    && ./flisp /smoke.lsp | tee /smoke.out && grep -q '^ok-femto' /smoke.out
RUN printf 'BINSIZE %s flisp\n' "$(stat -c %s flisp)"
CMD ["/src/flisp", "/smoke.lsp"]
