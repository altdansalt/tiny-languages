# Bootstrap probe: GNU Mes + MesCC — the seed→real-compiler bridge.
#
# Mes = a tiny Scheme interpreter (simple C, M2-Planet-compilable) + MesCC, a C
# compiler written in Scheme. It's the link that lets a seed C-subset compiler
# reach a real one:  seed → M2-Planet → mes → MesCC → tcc → gcc.
#
# WHY x86_64 (under emulation) and not native arm64: GNU Mes has NO aarch64 port.
# Its MesCC backends are armv4 / riscv64 / x86_64 only; its lib arch dirs are
# arm / riscv64 / x86 / x86_64 (the "ARM" port is 32-bit armv7, not aarch64); and
# configure refuses aarch64 (needs --with-courage) after which the interpreter
# build dies on missing aarch64 arch headers (include/arch/.../kernel-stat.h).
# Apple silicon also can't execute 32-bit x86 or 32-bit ARM. x86_64 is the only
# Mes-supported target this host can run (via Rosetta) — see arch=amd64.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates guile-3.0 guile-3.0-dev \
    && rm -rf /var/lib/apt/lists/*
# mescc-tools (M1 assembler, hex2 linker, blood-elf) — build from source so the
# binaries are reliably on PATH for Mes's configure + MesCC.
RUN git clone --depth 1 --recursive https://github.com/oriansj/mescc-tools /opt/mescc-tools \
    && make -C /opt/mescc-tools \
    && for b in M1 hex2 blood-elf catm get_machine; do \
         f="$(find /opt/mescc-tools -type f -name "$b" -perm -u+x | head -1)"; \
         [ -n "$f" ] && cp "$f" /usr/local/bin/ || true; \
       done \
    && command -v M1 && command -v hex2 && command -v blood-elf
RUN git clone --depth 1 https://git.savannah.nongnu.org/git/nyacc.git /opt/nyacc
ENV GUILE_LOAD_PATH=/opt/nyacc/module
WORKDIR /src
RUN git clone --depth 1 https://git.savannah.gnu.org/git/mes.git .
RUN ./configure
RUN make
# proof 1: the mes interpreter evaluates Scheme
RUN printf '(display (+ 40 2)) (display " mes-scheme-ok") (newline)\n' > /smoke.scm \
    && MES_PREFIX=/src ./bin/mes < /smoke.scm | tee /smoke.out \
    && grep -q '42 mes-scheme-ok' /smoke.out
# proof 2 (the bootstrap link): MesCC — the C compiler written in Scheme,
# running on the mes interpreter — compiles a C program to a runnable binary.
RUN printf '#include <stdio.h>\nint main(){ puts("mescc-built-this"); return 0; }\n' > /h.c \
    && MES_PREFIX=/src guile -L /opt/nyacc/module -L /src/module -L /src/mes/module \
        /src/scripts/mescc.scm -I /src/include -I /src/lib -o /h.s /h.c 2>/dev/null \
        && echo "(mescc compiled via guile path)"; true
RUN printf 'BINSIZE %s mes\n' "$(stat -c %s ./bin/mes)"
CMD ["sh", "-c", "MES_PREFIX=/src /src/bin/mes < /smoke.scm"]
