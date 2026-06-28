# onetrueawk — the one true AWK (Kernighan). Needs bison as yacc.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache bison
WORKDIR /src
RUN git clone --depth 1 https://github.com/onetrueawk/awk .
RUN make -j"$(nproc)" && cp a.out /usr/local/bin/awk
RUN awk 'BEGIN{print "ok-awk"}' | tee /smoke.out && grep -q '^ok-awk' /smoke.out
RUN printf 'BINSIZE %s awk\n' "$(stat -c %s /usr/local/bin/awk)"
CMD ["awk", "BEGIN{print \"ok-awk\"}"]
