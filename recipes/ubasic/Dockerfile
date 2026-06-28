# ubasic — tiny BASIC by Adam Dunkels (library + our small file-running driver).
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/adamdunkels/ubasic .
COPY main.c /src/driver.c
RUN cc -O2 -I. driver.c ubasic.c tokenizer.c -o ubasic
RUN printf '10 print 42\n20 end\n' > /smoke.bas \
    && ./ubasic /smoke.bas | tee /smoke.out && grep -q '42' /smoke.out
RUN printf 'BINSIZE %s ubasic\n' "$(stat -c %s ./ubasic)"
CMD ["/src/ubasic", "/smoke.bas"]
