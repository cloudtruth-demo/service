FROM ruby:2.7.1

ARG app_user_uid=61000
ARG app_user_gid=61000

ENV SVC_NAME="demo1" \
    SVC_ENV="production" \
    SVC_PORT="8888" \
    SVC_DIR="/srv/app" \
    CLOUDTRUTH_PROJECT="service-demo1" \
    BUNDLE_PATH="/srv/bundler" \
    BUILD_PACKAGES="" \
    APP_PACKAGES="bash curl less vim netcat tzdata apt-utils locales" \
    APP_USER="app"

# Thes env var definitions reference values from the previous definitions, so they need to be split off on their own.
# Otherwise, they'll receive stale values because Docker will read the values once before it starts setting values.
ENV BUNDLE_BIN="${BUNDLE_PATH}/bin" \
    GEM_HOME="${BUNDLE_PATH}" \
    PATH="${SVC_DIR}:${BUNDLE_BIN}:${PATH}"

# Create a non-root user for running the container
RUN groupadd -g $app_user_gid $APP_USER
RUN useradd --no-log-init --create-home --shell /bin/bash --gid $app_user_gid --uid $app_user_uid $APP_USER

RUN mkdir -p $SVC_DIR $BUNDLE_PATH
WORKDIR $SVC_DIR

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -q -y $BUILD_PACKAGES $APP_PACKAGES

# To set utf-8 locale for tmate
RUN sed -i -e 's/# \(en_US\.UTF-8 .*\)/\1/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
# Install tmate
RUN curl -Lo /tmp/tmate.tar.xz https://github.com/tmate-io/tmate/releases/download/2.4.0/tmate-2.4.0-static-linux-amd64.tar.xz && \
    cd /tmp && \
    tar xf /tmp/tmate.tar.xz && \
    mv tmate-2.4.0-static-linux-amd64/tmate /usr/bin/tmate && \
    rm -rf /tmp/tmate*

# Install cloudtruth cli
RUN (curl -sL https://github.com/cloudtruth/cloudtruth-cli/releases/latest/download/install.sh || wget -qO- https://github.com/cloudtruth/cloudtruth-cli/releases/latest/download/install.sh) |  sh

RUN gem install bundler
COPY Gemfile* $SVC_DIR/
RUN bundle install

COPY entrypoint.sh *.rb .env* $SVC_DIR/

# Give the app user access to the files it needs to write to
RUN mkdir -p log storage tmp
RUN chown -R $APP_USER:$APP_USER log storage tmp

RUN chmod 1777 /tmp
# change to the app user for running things
USER $APP_USER
# tmate needs ssh keys
RUN ssh-keygen -f ~/.ssh/id_rsa -N '' -t rsa

# Specify the script to use when running the container
ENTRYPOINT ["entrypoint.sh"]
# Start the main app process by sending the "app" parameter to the entrypoint
CMD ["app"]

EXPOSE $SVC_PORT
