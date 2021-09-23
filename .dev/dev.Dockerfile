# https://evilmartians.com/chronicles/ruby-on-whales-docker-for-ruby-rails-development
FROM ruby:3.0-slim-buster

ENV PG_MAJOR=13
# ENV NODE_MAJOR=13
# ENV BUNDLER_VERSION=2.1.4
# ENV YARN_VERSION=1.21.1

# Common dependencies
RUN apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    build-essential \
    gnupg2 \
    curl \
    less \
    git \
    nano \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

# Add PostgreSQL to sources list
RUN curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && echo 'deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main' $PG_MAJOR > /etc/apt/sources.list.d/pgdg.list

# # Add NodeJS to sources list
# RUN curl -sL https://deb.nodesource.com/setup_$NODE_MAJOR.x | bash -

# # Add Yarn to the sources list
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
#   && echo 'deb http://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list

# Application dependencies
# We use an external Aptfile for that
# COPY .dev/configs/Aptfile /tmp/Aptfile
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -yq dist-upgrade && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    libpq-dev \
    postgresql-client-$PG_MAJOR && \
    # nodejs \
    # yarn=$YARN_VERSION-1 && \
    # $(cat /tmp/Aptfile | xargs) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    truncate -s 0 /var/log/*log

# Faster Rubocop
RUN curl https://raw.githubusercontent.com/fohte/rubocop-daemon/master/bin/rubocop-daemon-wrapper -o /tmp/rubocop-daemon-wrapper
RUN mkdir -p /usr/local/bin/rubocop-daemon-wrapper
RUN mv /tmp/rubocop-daemon-wrapper /usr/local/bin/rubocop-daemon-wrapper/rubocop
RUN chmod +x /usr/local/bin/rubocop-daemon-wrapper/rubocop

ENV PATH /usr/local/bin/rubocop-daemon-wrapper:$PATH
ENV RUBOCOP_DAEMON_USE_BUNDLER true

# upgrade rubygems and bundler
RUN gem update --system --silent

# Run Rails Command as non root
RUN groupadd  -g 1000 admin && \
    useradd -m -g admin -u 1000 deploy
USER deploy

# Configure bundler and rails
ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=20 \
  BUNDLE_RETRY=3 \
  BUNDLE_APP_CONFIG=/home/deploy/.bundle \
  GEM_HOME=/home/deploy/.bundle \
  RAILS_ROOT=/home/deploy/app \
  RAILS_LOG_TO_STDOUT=1

# Configure RubyGems
COPY --chown=deploy:admin .gemrc ~/.gemrc

# Add aliases
# COPY --chown=deploy:admin .dev/.bash_aliases /home/deploy/.bash_aliases

# Uncomment this line if you want to run binstubs without prefixing with `bin/` or `bundle exec`
ENV PATH ${RAILS_ROOT}/bin:$PATH

# Create a directory for the app code
RUN mkdir -p ${RAILS_ROOT}
WORKDIR ${RAILS_ROOT}

COPY --chown=deploy:admin Gemfile Gemfile.lock ${RAILS_ROOT}/
RUN bundle install

# Copy the main application.
COPY --chown=deploy:admin . ${RAILS_ROOT}/
