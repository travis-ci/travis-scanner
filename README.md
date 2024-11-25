# Travis Scanner
Travisscanner is a service designed to automate log file scanning and analysis. It ingests log files, processes them using various plugins (currently Trivy and Detect Secrets), identifies vulnerabilities and security issues, and stores the results in a database and S3. The service also updates log files with anonymized sensitive information and triggers notifications for failed scans.

So any leaking secrets in job logs will be obfuscated/musked into estarics (*****), this improves security of TravisCI.



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
