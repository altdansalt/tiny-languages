# mruby — minimal Ruby (ISO subset), embeddable. Built via rake.
FROM alpine:3.20 AS build
RUN apk add --no-cache build-base git
RUN apk add --no-cache ruby ruby-rake
WORKDIR /src
RUN git clone --depth 1 https://github.com/mruby/mruby .
RUN rake -j"$(nproc)"
RUN BIN=$(find build -type f -name mruby -perm -u+x | head -1) && cp "$BIN" /usr/local/bin/mruby
RUN mruby -e 'puts "ok-mruby"' | tee /smoke.out && grep -q '^ok-mruby' /smoke.out
RUN printf 'BINSIZE %s mruby\n' "$(stat -c %s /usr/local/bin/mruby)"
CMD ["mruby", "-e", "puts \"ok-mruby\""]
