ARG DEBIAN_VERSION=bullseye-20250203-slim
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"
FROM ${RUNNER_IMAGE}
WORKDIR /app
RUN chown nobody /app

RUN apt-get update -y && \
    apt-get install -y libstdc++6 libc6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV=prod

# Only copy the final release from the build stage
COPY --chown=nobody:root _build/prod/rel/estore ./
COPY --chown=nobody:root README.md ./
RUN chmod +x /app/bin/server

USER nobody

CMD ["/app/bin/server"]
