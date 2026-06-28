# Bootstrap probe (self-hosting language): OCaml reproduces its own seed.
#
# PATHS.md #2. OCaml ships a tiny pre-compiled bytecode compiler in boot/
# (~2 MB, architecture-neutral). `make` builds the full compiler *using* that
# seed; `make bootstrap` then rebuilds boot/ WITH the freshly built compiler and
# iterates to a fixpoint — i.e. the compiler reproduces the very seed it was built
# from. That fixpoint is the self-hosting proof, and it's native aarch64 (unlike
# the Mes/tcc C-chain, which has no arm64 port). Deps: just a C compiler + make.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc make ca-certificates curl libc6-dev binutils \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN curl -fsSL https://github.com/ocaml/ocaml/archive/refs/tags/5.2.0.tar.gz \
        | tar xz --strip-components=1
RUN ./configure
# build the compiler from the shipped bytecode seed
RUN make -j"$(nproc)"
# self-host: rebuild the boot/ seed with the just-built compiler, to a fixpoint.
# "Fixpoint reached, bootstrap succeeded." == the compiler reproduces its own seed.
RUN make bootstrap 2>&1 | tee /boot.log \
    && grep -qi 'fixpoint reached, bootstrap succeeded' /boot.log
RUN make install
# proof: the installed compiler compiles + runs a program (bytecode, arch-neutral)
RUN printf 'let () = Printf.printf "ocaml-selfhost-ok %%s\\n" Sys.ocaml_version\n' > /h.ml \
    && ocamlc /h.ml -o /h && /h | tee /h.out \
    && grep -q 'ocaml-selfhost-ok 5.2.0' /h.out
RUN printf 'BINSIZE %s ocamlc\n' "$(stat -c %s "$(command -v ocamlc.byte || command -v ocamlc)")"
CMD ["/h"]
