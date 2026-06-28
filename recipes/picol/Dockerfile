# picol — tiny Tcl interpreter in ~550 lines by antirez (single file)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/antirez/picol .
RUN cc -O2 picol.c -o picol
RUN printf 'puts ok-picol\n' > /smoke.tcl \
    && ./picol /smoke.tcl | tee /smoke.out && grep -q '^ok-picol' /smoke.out
RUN printf 'BINSIZE %s picol\n' "$(stat -c %s ./picol)"
CMD ["/src/picol", "/smoke.tcl"]
