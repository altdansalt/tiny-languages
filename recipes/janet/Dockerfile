# janet — small functional lang, single-file amalgamation, musl-friendly
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/janet-lang/janet .
RUN make -j"$(nproc)"
RUN ./build/janet -e '(print "ok janet")' | tee /smoke.out \
    && grep -q '^ok janet' /smoke.out
RUN printf 'BINSIZE %s janet\n' "$(stat -c %s build/janet)"
CMD ["/src/build/janet", "-e", "(print \"ok janet\")"]
