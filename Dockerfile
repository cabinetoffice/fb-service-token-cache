FROM ruby:3.2.3-alpine3.19

RUN apk add build-base bash libcurl sqlite sqlite-dev sqlite-libs tzdata
RUN apk add --no-cache gcompat

ADD https://storage.googleapis.com/kubernetes-release/release/v1.30.0/bin/linux/amd64/kubectl /usr/local/bin/kubectl

ENV HOME=/config

RUN set -x && \
    apk add --no-cache curl ca-certificates && \
    chmod +x /usr/local/bin/kubectl && \
    # Create non-root user (with a randomly chosen UID/GUI).
    adduser kubectl -Du 2342 -h /config && \
    # Basic check it works.
    kubectl version --client

RUN addgroup -g 1001 -S appgroup && \
  adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

COPY Gemfile* .ruby-version ./

ARG BUNDLE_FLAGS
RUN gem install bundler
RUN bundle config set force_ruby_platform true
RUN bundle install --jobs 4

COPY . .

RUN chown -R 1001:appgroup /app

USER 1001

ENV APP_PORT 3000
EXPOSE $APP_PORT

ARG RAILS_ENV=production
CMD RAILS_ENV=${RAILS_ENV} bundle exec rails s -e ${RAILS_ENV} -p ${APP_PORT} --binding=0.0.0.0
