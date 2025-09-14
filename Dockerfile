ARG RUNNER_IMAGE="ubuntu:24.04"
FROM ${RUNNER_IMAGE}
RUN useradd -D -h /home/container container
WORKDIR /home/container

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV=prod

# Only copy the final release from the build stage
COPY --chown=container:container _build/prod/rel/estore ./
COPY --chown=container:container README.md ./
RUN chmod +x /home/container/bin/server

USER container
CMD ["/home/container/bin/server"]
