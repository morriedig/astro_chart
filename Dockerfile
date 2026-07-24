FROM ruby:3.2-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

# The web app's Gemfile references the astro_chart gem via path: "..",
# so the build context is the repo root and the gem sources are copied first.
WORKDIR /app
COPY astro_chart.gemspec CHANGELOG.md LICENSE ./
COPY lib ./lib

COPY web/Gemfile web/Gemfile.lock ./web/
WORKDIR /app/web
RUN bundle config set --local without test && bundle install

COPY web ./

ENV RACK_ENV=production
EXPOSE 8080
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:8080", "config.ru"]
