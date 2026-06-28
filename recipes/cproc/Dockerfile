# cproc — small C11 compiler frontend on the QBE backend (both built here).
# Native arm64: QBE supports aarch64, binutils provides as/ld.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git binutils musl-dev
WORKDIR /src
# Use cproc author's matched QBE fork: it tracks the IR cproc emits, and its
# Makefile has the correct "#define Deftgt T_arm64" (the 8l/qbe mirror has a
# "$define" typo on the aarch64 branch AND lags cproc's expected IR).
RUN git clone --depth 1 https://github.com/michaelforney/qbe qbe \
    && make -C qbe -j"$(nproc)"
RUN git clone --depth 1 https://github.com/michaelforney/cproc cproc \
    && cd cproc && ./configure --with-qbe=/src/qbe/obj/qbe && make -j"$(nproc)"
RUN printf '#include <stdio.h>\nint main(){printf("ok-cproc\\n");return 0;}\n' > /smoke.c \
    && /src/cproc/cproc -o /smoke /smoke.c && /smoke | tee /smoke.out \
    && grep -q '^ok-cproc' /smoke.out
RUN printf 'BINSIZE %s cproc\n' "$(stat -c %s cproc/cproc)"
CMD ["/smoke"]
