FROM ruby:2.7

WORKDIR /app

COPY Gemfile* .
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["puma", "-C", "config/puma.rb"]
