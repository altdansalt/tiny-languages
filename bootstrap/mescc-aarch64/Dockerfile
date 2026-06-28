# PROOF-OF-CONCEPT: a NEW aarch64 backend for GNU Mes's MesCC compiler.
#
# The native-arm64 bootstrap stalls at M2-Planet because GNU Mes has no aarch64
# port (its MesCC targets armv4/riscv64/x86_64). This adds one: module/mescc/
# aarch64/{info,as}.scm + a 3-line patch to mescc.scm. The code generator emits
# the whole-instruction M1 macros already defined and tested in M2libc's
# aarch64_defs.M1, so it needs no new instruction encodings — and it links through
# the exact same proven M2libc crt/libc/ELF stack that stage0-posix uses (the
# M2libc :_start calls :FUNCTION_main, which is what MesCC emits).
#
# Milestone 1: compile `int main(){return 42;}` with the new backend and run it.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates build-essential guile-3.0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /b
RUN git clone --depth 1 https://git.savannah.gnu.org/git/mes.git mes
RUN git clone --depth 1 --recursive https://github.com/oriansj/mescc-tools mt \
    && make -C mt ; \
    for x in M1 hex2; do f="$(find mt -type f -name "$x" -perm -u+x | head -1)"; cp "$f" /usr/local/bin/; done \
    && command -v M1 && command -v hex2
# M2libc aarch64: the tested instruction macros + libc + ELF header (via stage0)
RUN git clone --depth 1 --recursive https://github.com/oriansj/stage0-posix s0
ENV M2=/b/s0/M2libc/aarch64
# nyacc: the C99 parser MesCC's front end is built on
RUN git clone --depth 1 https://git.savannah.nongnu.org/git/nyacc.git /opt/nyacc
ENV GUILE_LOAD_PATH=/opt/nyacc/module

# install the new backend + patch the arch dispatch
RUN mkdir -p mes/module/mescc/aarch64
COPY overlay/info.scm mes/module/mescc/aarch64/info.scm
COPY overlay/as.scm   mes/module/mescc/aarch64/as.scm
COPY overlay/crt1.M1  /b/crt1.M1
COPY overlay/patch.sed /patch.sed
# Mes-style aarch64 ELF templates: header (riscv64's, with e_machine -> AArch64
# 0xB7) + footer (pure symbol/string tables, arch-independent). The header's
# e_entry points at :_start (our crt1); the footer defines :ELF_end.
RUN sed 's/^f3 00 /b7 00 /' mes/lib/linux/riscv64-mes/elf64-header.hex2 > /b/header.hex2 \
    && grep -q '^b7 00 ' /b/header.hex2 \
    && cp mes/lib/linux/riscv64-mes/elf64-footer-single-main.hex2 /b/footer.hex2
RUN cd mes && sed -i -f /patch.sed module/mescc/mescc.scm \
    && grep -q 'aarch64-info' module/mescc/mescc.scm && echo "mescc.scm patched"
RUN printf 'int main () { return 42; }\n' > /b/main.c
RUN printf '(use-modules (mescc))\n(mescc:main (command-line))\n' > /b/drive.scm

# --- compile: C -> aarch64 M1 assembly via the new backend ---
ENV MES_PREFIX=/b/mes
RUN cd /b/mes && ( guile -L module -L /opt/nyacc/module -L . /b/drive.scm --arch=aarch64 -S /b/main.c -o /b/main.s 2>&1 | tee /b/compile.log ); \
    echo "================ emitted main.s ================"; cat /b/main.s 2>/dev/null || echo "(no main.s produced)"

# --- assemble crt1 + MesCC output, expanding M2libc's aarch64 macros ---
RUN M1 --architecture aarch64 --little-endian \
        -f "$M2/aarch64_defs.M1" -f /b/crt1.M1 -f /b/main.s -o /b/code.hex2 \
    && echo "M1 assembled crt1 + MesCC output"
# --- link: Mes aarch64 ELF header + code + footer -> a real ELF ---
RUN hex2 --architecture aarch64 --little-endian --base-address 0x00400000 \
        -f /b/header.hex2 -f /b/code.hex2 -f /b/footer.hex2 -o /b/main.elf \
    && chmod +x /b/main.elf \
    && head -c4 /b/main.elf | grep -qa ELF && echo "linked a valid aarch64 ELF"
# --- run it: the new backend's output must exit 42 ---
RUN /b/main.elf; rc=$?; echo "main.elf exit code = $rc"; [ "$rc" -eq 42 ] \
    && echo "SUCCESS: MesCC-aarch64 compiled and ran int main(){return 42;}"
RUN printf 'BINSIZE %s main.elf\n' "$(stat -c %s /b/main.elf)"
CMD ["sh", "-c", "/b/main.elf; echo \"MesCC-aarch64 built main.elf; it returned $?\""]
