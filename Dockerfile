ARG PHP_VERSION

FROM php:${PHP_VERSION}-fpm-alpine as base
ENV APCU_VERSION=5.1.17 \
    ICU_VERSION=64.2 \
    PHPREDIS_VERSION=4.3.0 \
    LD_PRELOAD=/usr/lib/preloadable_libiconv.so
# https://pecl.php.net/package/apcu
# https://github.com/unicode-org/icu/releases
# https://github.com/phpredis/phpredis/releases
# https://github.com/docker-library/php/issues/240
RUN set -xe \
 && apk add --no-cache \
      libbz2 \
      libstdc++ \
      libzip \
      postgresql-dev \
      zlib \
 && apk add --no-cache --virtual .build-deps \
      $PHPIZE_DEPS \
      bzip2-dev \
      libzip-dev \
      zlib-dev \
 && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted \
      gnu-libiconv \
 && curl -sS -o /tmp/icu.tar.gz -L https://github.com/unicode-org/icu/releases/download/release-$(set +x && echo $ICU_VERSION | tr '.' '-' && set -x)/icu4c-$(set +x && echo $ICU_VERSION | tr '.' '_' && set -x)-src.tgz \
 && tar -zxf /tmp/icu.tar.gz -C /tmp && cd /tmp/icu/source \
 && ./configure --prefix=/usr/local --disable-layout --disable-tests --disable-samples \
 && make -j && make -j install \
 && pecl install \
      apcu-${APCU_VERSION} \
      redis-${PHPREDIS_VERSION} \
 && docker-php-ext-configure intl --with-icu-dir=/usr/local \
 && docker-php-ext-configure zip --with-libzip \
 && docker-php-ext-install -j$(nproc) \
      bz2 \
      intl \
      opcache \
      pcntl \
      pdo_pgsql \
      zip \
 && docker-php-ext-enable \
      apcu \
      redis \
 && apk del --no-network .build-deps \
 && rm -rf /tmp/*
RUN set -xe \
 && curl -A 'Docker' -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/alpine/amd64/$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
 && mkdir -p /tmp/blackfire \
 && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
 && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
 && printf 'extension=blackfire.so\nblackfire.agent_socket=tcp://0.0.0.0:8707\nblackfire.server_id=${BLACKFIRE_SERVER_ID}\nblackfire.server_token=${BLACKFIRE_SERVER_TOKEN}\n' > $PHP_INI_DIR/conf.d/blackfire.ini \
 && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz \
 && curl -s -L https://packages.blackfire.io/binaries/blackfire-agent/${BLACKFIRE_VERSION}/blackfire-cli-linux_static_amd64 -o /usr/local/bin/blackfire && chmod +x /usr/local/bin/blackfire
WORKDIR /srv

FROM base as base-dev
RUN set -xe \
 && apk add --no-cache \
      su-exec \
 && addgroup bar \
 && adduser -D -h /home -s /bin/sh -G bar foo \
 && chown foo:bar /home
COPY .docker/website/rootfs/sbin /sbin
ENTRYPOINT ["entrypoint"]

FROM base-dev as tools
ENV COMPOSER_HOME=/tmp/composer \
    COMPOSER_CACHE_DIR=/home/.composer/cache \
    ENV="/etc/profile" \
    PATH=vendor/bin:$PATH
RUN set -xe \
 && echo '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories \
 && apk add --no-cache \
      curl \
      git@edge \
      nodejs-current@edge \
      npm@edge \
      openssh-client
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
RUN composer global require \
      pyrech/composer-changelogs \
      symfony/flex

FROM base-dev as http-dev
RUN set -xe \
 && apk add --no-cache \
      dcron \
      nginx \
      supervisor
COPY .docker/website/rootfs /
CMD ["supervisord", "--nodaemon", "--configuration", "/etc/supervisor/website.conf"]
EXPOSE 80

# https://gist.github.com/deguif/575c178bafe25a26ec1892833cd18917
