### Base ###

FROM ruby:3.1.2-alpine as base

# Install requirements to run the app
RUN apk add --no-cache --update \
                                libpq \
                                tzdata

# Bundle config
RUN bundle config set --global no-cache 'true' && \
    bundle config set --global frozen 'true' && \
    bundle config set --global without 'development test' && \
    bundle config set --global jobs `expr $(cat /proc/cpuinfo | grep -c 'cpu cores')` && \
    bundle config set --global retry 3

# Set app workdir
WORKDIR /app


### Build ###

FROM base as builder

# Install requirements to build the app
RUN apk add --no-cache --update \
                                git \
                                build-base \
                                postgresql-dev

# Copy gemfiles into the container
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install


### App ###

FROM base

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy app files
COPY . ./

# Set entrypoint
ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["bundle", "exec", "rails", "server"]
