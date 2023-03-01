FROM ruby:3.1.2-slim-buster

COPY app.rb /app/

WORKDIR /app

RUN gem install sinatra

EXPOSE 5000

CMD ["ruby", "app.rb"]
