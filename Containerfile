# ---------- base ----------
FROM ghcr.io/forem/ruby:3.3.0@sha256:9cda49a45931e9253d58f7d561221e43bd0d47676b8e75f55862ce1e9997ab5c AS base

# інколи всередині образу немає /usr/bin/bash — робимо симлінк
USER root
RUN ln -sf /bin/bash /usr/bin/bash

ENV APP_USER=forem \
    APP_UID=1000 \
    APP_GID=1000 \
    APP_HOME=/opt/apps/forem \
    LD_PRELOAD=libjemalloc.so.2

# юзер/група додатку
RUN groupadd -g "${APP_GID}" "${APP_USER}" && \
    useradd -u "${APP_UID}" -g "${APP_GID}" -d "${APP_HOME}" -m "${APP_USER}"

# ---------- builder ----------
FROM base AS builder

ARG TARGETARCH
USER root

# системні залежності для зборки gems/node (canvas etc.)
RUN rm -f /etc/apt/sources.list.d/nodesource.list* \
    && apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      libcurl4-openssl-dev \
      libffi-dev \
      libxml2-dev \
      libxslt-dev \
      libpcre3-dev \
      libpq-dev \
      pkg-config \
      libpixman-1-dev \
      libcairo2-dev \
      libpango1.0-dev \
      curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# dockerize (чекає сервіси на старті)
ENV DOCKERIZE_VERSION=v0.7.0
RUN curl -fsSLO https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-${TARGETARCH}-${DOCKERIZE_VERSION}.tar.gz \
 && tar -C /usr/local/bin -xzvf dockerize-linux-${TARGETARCH}-${DOCKERIZE_VERSION}.tar.gz \
 && rm dockerize-linux-${TARGETARCH}-${DOCKERIZE_VERSION}.tar.gz

# bundler
ENV BUNDLER_VERSION=2.4.17 \
    BUNDLE_SILENCE_ROOT_WARNING=true \
    BUNDLE_SILENCE_DEPRECATIONS=true
RUN gem install -N bundler:${BUNDLER_VERSION}

USER "${APP_USER}"
WORKDIR "${APP_HOME}"

# додаємо файли для bundler спочатку — кеш шарів
COPY --chown=${APP_UID}:${APP_GID} .ruby-version Gemfile Gemfile.lock ${APP_HOME}/
COPY --chown=${APP_UID}:${APP_GID} vendor/cache ${APP_HOME}/vendor/cache

# не використовувати глобальний APP_CONFIG — пишемо в локальну .bundle
ENV BUNDLE_APP_CONFIG="${APP_HOME}/.bundle"
RUN mkdir -p "${BUNDLE_APP_CONFIG}" && \
    touch "${BUNDLE_APP_CONFIG}/config" && \
    bundle config --local build.sassc --disable-march-tune-native && \
    bundle config --local without development:test && \
    BUNDLE_FROZEN=true bundle install --deployment --jobs 4 --retry 5 && \
    find "${APP_HOME}"/vendor/bundle -name "*.c" -delete && \
    find "${APP_HOME}"/vendor/bundle -name "*.o" -delete

# весь код після інсталяції gems
COPY --chown=${APP_UID}:${APP_GID} . ${APP_HOME}

# статика
RUN mkdir -p "${APP_HOME}"/public/{assets,images,packs,podcasts,uploads}
# buildx/qemu інколи повільний — збільшуємо таймаут для yarn
RUN echo 'httpTimeout: 300000' >> ~/.yarnrc.yml

# install node deps та препрокомпіляція ассетів
RUN NODE_ENV=production yarn install && \
    RAILS_ENV=production NODE_ENV=production bundle exec rake assets:precompile && \
    rm -rf node_modules

# метадані збірки (опційно, CI може переписати)
ARG VCS_REF=unspecified
RUN date -u +'%Y-%m-%dT%H:%M:%SZ' >> "${APP_HOME}/FOREM_BUILD_DATE" && \
    echo "${VCS_REF}" >> "${APP_HOME}/FOREM_BUILD_SHA"

# ---------- (необов'язково) testing ----------
FROM builder AS testing
# якщо раптом треба тести — можна добити сюди spec’и, але в прод це не піде
# ENTRYPOINT/CMD такі самі, як у builder, якщо потрібно.

# ---------- (необов'язково) development ----------
FROM base AS development
USER root

# dev-інструменти/клієнти ставимо ЛИШЕ в dev (НЕ в production!)
RUN rm -f /etc/apt/sources.list.d/nodesource.list* \
    && apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl less \
      libpq-dev postgresql-client \
      libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 \
      libnss3 libxss1 libasound2 libxtst6 xauth xvfb \
      libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev && \
    rm -rf /var/lib/apt/lists/*

# для локальної розробки:
RUN gem update --system && gem install bundler

USER "${APP_USER}"
WORKDIR /app
EXPOSE 3000
CMD ["/usr/bin/bash"]

# ---------- production (ФІНАЛЬНИЙ, мінімальний) ----------
FROM base AS production
USER root

# тільки bundler + системний юзер (жодних apt-get у прод!)
ENV BUNDLER_VERSION=2.4.17 BUNDLE_SILENCE_ROOT_WARNING=1
RUN gem install -N bundler:${BUNDLER_VERSION}

# (забезпечуємо існування APP_HOME та власника — якщо треба повторно)
RUN mkdir -p ${APP_HOME} && chown "${APP_UID}:${APP_GID}" "${APP_HOME}"

# копіюємо ГООООТОВУ збірку з builder
COPY --from=builder --chown="${APP_USER}":"${APP_USER}" ${APP_HOME} ${APP_HOME}

USER "${APP_USER}"
WORKDIR "${APP_HOME}"

VOLUME "${APP_HOME}"/public/

ENTRYPOINT ["./scripts/entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
