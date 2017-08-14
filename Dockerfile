FROM alpine:3.6

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
    && { \
        echo 'install: --no-document'; \
        echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.4
ENV RUBY_VERSION 2.4.0
ENV RUBY_DOWNLOAD_SHA256 152fd0bd15a90b4a18213448f485d4b53e9f7662e1508190aa5b702446b29e3d
ENV RUBYGEMS_VERSION 2.6.8

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
# readline-dev vs libedit-dev: https://bugs.ruby-lang.org/issues/11869 and https://github.com/docker-library/ruby/issues/75
RUN set -ex \
    \
    && apk add --no-cache --virtual .ruby-builddeps \
        autoconf \
        bison \
        bzip2 \
        bzip2-dev \
        ca-certificates \
        coreutils \
        gcc \
        gdbm-dev \
        glib-dev \
        libc-dev \
        libffi-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        make \
        ncurses-dev \
        openssl \
        openssl-dev \
        procps \
        readline-dev \
        ruby \
        tar \
        yaml-dev \
        zlib-dev \
    \
    && wget -O ruby.tar.gz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.gz" \
    && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
    \
    && mkdir -p /usr/src/ruby \
    && tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
    && rm ruby.tar.gz \
    \
    && cd /usr/src/ruby \
    \
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
    && { \
        echo '#define ENABLE_PATH_CHECK 0'; \
        echo; \
        cat file.c; \
    } > file.c.new \
    && mv file.c.new file.c \
    \
    && autoconf \
# the configure script does not detect isnan/isinf as macros
    && ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
        ./configure --disable-install-doc --enable-shared \
    && make -j"$(getconf _NPROCESSORS_ONLN)" \
    && make install \
    && make distclean \
    \
    && runDeps="$( \
        scanelf --needed --nobanner --recursive /usr/local \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --virtual .ruby-rundeps $runDeps \
        bzip2 \
        ca-certificates \
        libffi-dev \
        openssl-dev \
        yaml-dev \
        procps \
        zlib-dev \
    && cd / \
    && rm -r /usr/src/ruby \
    \
    && gem update --system "$RUBYGEMS_VERSION"

ENV BUNDLER_VERSION 1.13.6

RUN gem install bundler --version "$BUNDLER_VERSION"
# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_BIN="$GEM_HOME/bin" \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
    && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

# install node
ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 8.0.0

RUN apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        binutils-gold \
        curl \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python \
  # gpg keys listed at https://github.com/nodejs/node#release-team
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
  ; do \
    gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
  done \
    && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.gz" \
    && curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION.tar.gz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "./node-v$NODE_VERSION.tar.gz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && make distclean \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.gz" SHASUMS256.txt.asc SHASUMS256.txt

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY ./slate/Gemfile /usr/src/app/
COPY ./slate/Gemfile.lock /usr/src/app/
RUN bundle install

COPY ./slate /usr/src/app

VOLUME /usr/src/app/source
EXPOSE 4567

RUN apk del .ruby-builddeps
RUN apk del .build-deps

CMD ["bundle", "exec", "middleman", "server", "--watcher-force-polling"]
