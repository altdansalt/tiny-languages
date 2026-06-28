# yoctolisp — tiny Scheme-like Lisp by fragglet ("written in a weekend")
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/fragglet/yoctolisp .
RUN make
RUN printf '(print (+ 40 2))\n' > /smoke.yl \
    && ./yoctolisp /smoke.yl 2>&1 | tee /smoke.out && grep -q '42' /smoke.out
RUN printf 'BINSIZE %s yoctolisp\n' "$(stat -c %s ./yoctolisp)"
CMD ["/src/yoctolisp", "/smoke.yl"]

