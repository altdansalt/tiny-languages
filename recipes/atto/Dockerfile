# atto — insanely simple self-hosted functional language (Rust)
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache cargo
WORKDIR /src
RUN git clone --depth 1 https://github.com/zesterer/atto .
RUN cargo build --release
RUN cp target/release/atto /usr/local/bin/atto
# run a committed example and just prove the interpreter executes it
RUN SAMPLE=$(find examples -name '*.at' | head -1) && echo "running $SAMPLE" \
    && atto "$SAMPLE" | tee /smoke.out && test -s /smoke.out
RUN printf 'BINSIZE %s atto\n' "$(stat -c %s /usr/local/bin/atto)"
CMD ["sh", "-c", "atto $(find /src/examples -name '*.at' | head -1)"]
