# partcl — micro Tcl (~600 LOC) by zserge. tcl.c has a stdin REPL main.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
WORKDIR /src
RUN git clone --depth 1 https://github.com/zserge/partcl .
RUN cc -Os -Wall tcl.c -o tcl
# REPL evaluates each command and prints "result> <value>"
RUN printf '+ 40 2\n' | ./tcl | tee /smoke.out && grep -q 'result> 42' /smoke.out
RUN printf 'BINSIZE %s tcl\n' "$(stat -c %s ./tcl)"
CMD ["sh", "-c", "printf '+ 40 2\\n' | /src/tcl"]
