# goawk — POSIX AWK in Go (also compiles to wasm)
FROM alpine:3.20 AS build
RUN apk add --no-cache git go
WORKDIR /src
RUN git clone --depth 1 https://github.com/benhoyt/goawk .
ENV GOFLAGS=-buildvcs=false GOTOOLCHAIN=local
RUN go build -o /usr/local/bin/goawk .
RUN goawk 'BEGIN{print "ok-goawk"}' | tee /smoke.out && grep -q '^ok-goawk' /smoke.out
RUN printf 'BINSIZE %s goawk\n' "$(stat -c %s /usr/local/bin/goawk)"
CMD ["goawk", "BEGIN{print \"ok-goawk\"}"]
