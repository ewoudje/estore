ARG RUNNER_IMAGE="ubuntu:24.04"
FROM ${RUNNER_IMAGE}

WORKDIR /app
RUN useradd -m -d /home/container -s /bin/bash container
RUN chown container /app

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
RUN chmod +x /app/bin/server
RUN chmod -R ugo+rw /app/lib/tzdata-1.1.3/priv

WORKDIR /home/container
COPY --chown=container:container README.md ./
COPY deployment/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER container
ENV USER=container HOME=/home/container
CMD ["/bin/bash", "/entrypoint.sh"]
