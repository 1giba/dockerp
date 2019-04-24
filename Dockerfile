#
# Nginx
#
FROM nginx:1.15-alpine

#
# Author
#
LABEL maintainer="Gilberto Junior <olamundo@gmail.com>"

#
# Add key
#
ADD https://dl.bintray.com/php-alpine/key/php-alpine.rsa.pub /etc/apk/keys/php-alpine.rsa.pub

#
# Copy scripts
#
COPY ./scripts/docker-nginx-change.sh /usr/bin/docker-nginx-change
COPY ./scripts/docker-timezone-change.sh /usr/bin/docker-timezone-change
COPY ./scripts/docker-user-create.sh /usr/bin/docker-user-create
COPY ./scripts/docker-vhost-change.sh /usr/bin/docker-vhost-change

#
# Copy templates
#
COPY ./templates /templates

#
# Default values
#
ARG NODE_VERSION='8.15.1'
ARG YARN_VERSION='1.12.3'

#
# Env vars
#
ENV PGID 1000
ENV PUID 1000
ENV DEV_GROUP docker
ENV DEV_USER docker
ENV NGINX_SERVER_NAME app.dev.local
ENV NGINX_DOCUMENT_ROOT /var/www
ENV NGINX_WORKER_PROCESSES auto
ENV NGINX_WORKER_CONNECTIONS 1024
ENV NGINX_KEEPALIVE_TIMEOUT 65
ENV NGINX_EXPOSE_VERSION off
ENV NGINX_CLIENT_BODY_BUFFER_SIZE 16k
ENV NGINX_CLIENT_MAX_BODY_SIZE 1m
ENV NGINX_LARGE_CLIENT_HEADER_BUFFERS "4 8k"
ENV PHP_FPM_FAST_CGI 127.0.0.1:9000
ENV NODE_VERSION ${NODE_VERSION}
ENV YARN_VERSION ${YARN_VERSION}
ENV TIMEZONE UTC
ENV ESCAPE '$'
ENV COMPOSER_ALLOW_SUPERUSER 1

#
# Create group and user
#
RUN set -x \
    && addgroup -g $PGID $DEV_USER \
    && adduser -u $PUID -D -G $DEV_GROUP $DEV_USER \
#
# Install Libs
#
    && apk add --no-cache \
        bash \
        curl \
        supervisor \
        git \
        gettext \
        tzdata \
        libjpeg-turbo \
        libxml2 \
#
# Configure timezone
#
    && cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && echo $TIMEZONE > /etc/timezone \
    && apk del tzdata \
#
# Redirect output to container
#
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
#
# Install PHP
#
    && echo "@php https://dl.bintray.com/php-alpine/v3.9/php-7.3" >> /etc/apk/repositories \
    && apk update \
    && apk add --no-cache \
        php@php \
        php-curl@php \
        php-dom@php \
        php-fpm@php \
        php-gettext@php \
        php-iconv@php \
        php-json@php \
        php-mbstring@php \
        php-openssl@php \
        php-pdo@php \
        php-phar@php \
        php-session@php \
        php-xdebug@php \
        php-xml@php \
        php-zlib@php \
#
# Create symlinks
#
    && ln -sf /etc/php7 /etc/php \
    && ln -sf /usr/bin/php7 /usr/bin/php \
    && ln -sf /usr/sbin/php-fpm7 /usr/bin/php-fpm \
    && ln -sf /usr/lib/php7 /usr/lib/php \
#
# Install composer
#
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer  \
    && composer global require hirak/prestissimo \
#
# Configure nginx & php
#
    && envsubst < /templates/nginx.conf.tpl > /etc/nginx/nginx.conf \
    && envsubst < /templates/nginx.host.tpl > /etc/nginx/conf.d/default.conf \
    && envsubst < /templates/php.custom.ini.tpl > /etc/php/conf.d/custom.ini \
    && envsubst < /templates/php-fpm.d.tpl > /etc/php/php-fpm.d/zz-docker.conf \
#
# Create workdir
#
    && mkdir -p /var/www \
#
# Install Node
#
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        binutils-gold \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python \
    && for key in \
        94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
        FD3A5288F042B6850C66B31F09FE44734EB7990E \
        71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
        DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
        C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
        B9AE9905FFD7803F25714661B63B535A4C206CA9 \
        56730D5401028683275BD23C23EFEFE93C4CFFFE \
        77984A986EBC2AA786BC0F66B01FBB92821C587A \
        8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    ; do \
        gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
        gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && apk del .build-deps \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
#
# Install Yarn
#
    && apk add --no-cache --virtual .build-deps-yarn gnupg tar \
    && for key in \
        6A010C5166006599AA17F08146C2130DFD2497F5 \
    ; do \
        gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
        gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
    && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
    && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && mkdir -p /opt \
    && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
    && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && apk del .build-deps-yarn \
#
# Create a php file
#
    && echo "<?php phpinfo();" > /var/www/index.php  \
    && chown -R ${DEV_USER}:${DEV_GROUP} /home/${DEV_USER} \
    && chown -R ${DEV_USER}:${DEV_GROUP} /var/www \
#
# Clear
#
    && rm -rf /tmp/* /var/cache/apk/* /usr/share/man

#
# Copy configs
#
COPY ./config/home/.bashrc /templates/.bashrc
COPY ./config/home/.bashrc /home/${DEV_USER}/.bashrc
COPY ./config/php/xdebug.ini /etc/php7/conf.d/xdebug.ini
COPY ./config/supervisor/docker.ini /etc/supervisor.d/docker.ini

#
# Init
#
WORKDIR /var/www

STOPSIGNAL SIGTERM

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]