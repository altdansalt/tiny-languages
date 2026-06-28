# m4 — macro processor (Turing-complete). Build from release tarball (git needs
# a heavy gnulib bootstrap; the tarball is self-contained).
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base
RUN apk add --no-cache wget
WORKDIR /src
RUN wget -q https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz && tar xf m4-1.4.19.tar.gz
WORKDIR /src/m4-1.4.19
RUN ./configure && make -j"$(nproc)"
RUN cp src/m4 /usr/local/bin/m4
RUN printf 'define(greet,ok-m4)greet\n' | m4 | tee /smoke.out && grep -q '^ok-m4' /smoke.out
RUN printf 'BINSIZE %s m4\n' "$(stat -c %s /usr/local/bin/m4)"
CMD ["sh", "-c", "printf 'define(greet,ok-m4)greet\\n' | m4"]
