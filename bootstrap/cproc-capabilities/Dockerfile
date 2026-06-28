# Bootstrap probe: WHAT CAN CPROC COMPILE? An expectation-encoded capability
# matrix for the cproc+QBE C compiler (see also recipes/cproc, cproc-selfhost).
#
# cproc is a near-complete C11 front end emitting QBE SSA IR (backend targets
# arm64/amd64/riscv64). This probe pins down its real envelope: a matrix of C11
# features + GNU extensions + three real programs, each tagged with its expected
# PASS/FAIL. The build fails if cproc deviates — so the "what it can/can't compile"
# claims in BOOTSTRAP.md stay honest. Same alpine/musl toolchain as recipes/cproc.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git binutils musl-dev
WORKDIR /src
# build the cproc toolchain (qbe backend + cproc driver/compiler) — see recipes/cproc
RUN git clone --depth 1 https://github.com/omenos/mirror-qbe qbe \
    && make -C qbe -j"$(nproc)" \
    && cp qbe/qbe /usr/local/bin/qbe
RUN git clone --depth 1 https://github.com/michaelforney/cproc cproc \
    && cd cproc && ./configure --with-qbe=/usr/local/bin/qbe && make -j"$(nproc)" \
    && cp cproc cproc-qbe /usr/local/bin/
COPY probe.sh /probe.sh
# the smoke IS the matrix: run it, keep the report, gate the build on zero mismatches
RUN sh /probe.sh > /capabilities.txt 2>&1; rc=$?; cat /capabilities.txt; [ "$rc" -eq 0 ]
RUN printf 'BINSIZE %s cproc\n' "$(stat -c %s /usr/local/bin/cproc)"
CMD ["cat", "/capabilities.txt"]
