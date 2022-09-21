# Travis Scanner

## Setup

### Build app image
```
docker compose build
```

### Install gems
```
docker compose run travis_scanner bundle install
```

### Database
#### Run postgresql and redis
```
docker compose up -d postgres redis
```

#### Prepare DB
##### Create database, run migrations and add seed entries.
```
docker compose run travis_scanner bundle exec rails db:setup
```

## Run app
```
docker compose up
```

## Run tests
```
docker compose run travis_scanner bundle exec rspec
```
