# Rails + Docker setup

This repo is is a reference to get set up developing rails application with docker on best practises for TDD workflow.

## How is this intended to be used?

1. Clone and initialize your repo
2. Build your development docker image
3. Generate a rails application
4. Add and configure testing gems

**Pre-requisites**

1. `docker -v` should work
2. `docker-compose -v` should work
3. `git --version` should work

## 1. Clone repo and initialize repo

Shallow clone the repo into a folder(`rails-app-name`) you want your rails app to live and initialize you git repo

```bash
git clone git@gitlab.com:nifty-nice/rails-docker.git rails-app-name --depth 1 -b master

cd rails-app-name
rm -rf .git

# Initialize repo
git init
git add .
git remote add origin <your-repo-link>
git commit -m 'Initial Commit'
git push -u origin master
```

The project is divided into the app section(`./`) and the docker development (`.dev`) section.

```
.
├── .dev
│   ├── .docker-sync
│   ├── configs
│   │   ├── .bash_aliases
│   │   ├── .env
│   │   ├── .psqlrc
│   │   └── Aptfile
│   ├── dev.Dockerfile
│   ├── docker-compose-dev.yaml
│   ├── docker-compose.example.yaml
│   ├── docker-compose.yaml
│   └── docker-sync.yml
├── .dockerignore
├── .editorconfig
├── Dockerfile
├── Gemfile
├── Gemfile.lock
└── README.md
```

## 2. Build development image

You will want to look through the `dev.Dockerfile` and `docker-compose.yaml` files if you want to customize the build.
The configurations are adapted from [this blog](https://evilmartians.com/chronicles/ruby-on-whales-docker-for-ruby-rails-development) which you should read to understand what's going on in the compose file.

The `docker-compose.example.yaml` file contains further services that you could adopt, including a `mongodb` related services.

First build the images, then set the desired rails version in the `Gemfile` then run bundler

```sh
docker-compose build
#  Set rails version in Gemfile
docker compose run <rails-service> --rm bundle install
```
Your Gemfile.lock file will be re-created.

### Aliases

There are aliases defined in `.dev/configs/.bash_aliases` that are active when running an interactive shell. i.e to use them, you need to be _logged in_ to the container.

```bash
docker-compose exec rails bash
# after which you can run
be guard
```
## 3. Generate Rails application

With the image built, generate a new rails app.

```bash
docker-compose run --rm rails bundle exec rails new . --database postgresql
## or for api-only
docker-compose run --rm rails bundle exec rails new . --api --database postgresql

# commit your app
git add .
git commit -m 'Generated App'
```

The command will request to overwrite this [README.md file](https://gitlab.com/nifty-nice/rails-docker/-/blob/master/README.md). It will also pick the containing folder name as the app name.

If you built a rails api only app, you can comment out the asset pipeline dependancies `node` and `yarn` in the `./.dev/dev.Dockerfile` and `./Dockerfile`. Makes for a smaller image.

### Setup the database

In docker-compose we have the ENV variable
`DATABASE_URL: postgresql://postgres:mysecretpassword@postgres:5432` which configures the database. However, this configures 1 environment and rails db:create will have errors when trying to create test db.

If you prefer,
Configure the database credentials in `/app-name/app/config/database.yml`

```yaml
# config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5
  url: <%= ENV['DATABASE_URL'] %>
```

Run database migration and then start the rails docker development environment

```bash
# Create Database
docker-compose run --rm rails bundle exec rails db:create

# start containers with rebuilt image due to new Gemfile
docker-compose up --build -d
```

Navigate to [http://localhost:3000](http://localhost:3000) and you should see the default rails page. To stop the application run `docker-compose down`

> Note: The database is persisted using the volumes configured in `docker-compose`

Finally commit your code

```bash
git add .
git commit -m 'App Initialized'
```

You may want to set up [Gitlab CI/CD](#Gitlab-CI/CD) pipeline to deploy a blank app on kubernetes

## Add ruby gems

### 1. Add `rails console` gems (all env)

`group :global`

1. [pry-rails](https://github.com/rweng/pry-rails) - use pry with `rails console`
2. [awesome_print](https://github.com/awesome-print/awesome_print) - formatted output for ruby objects. Use with `ap object` in console.

### 2. Add debugging gems

`group :development, :test`

1. [`gem 'pry-byebug'`](https://github.com/deivid-rodriguez/pry-byebug) - use the byebug debugger within the pry console
2. [`gem 'pry-alias'`](https://github.com/kentaroi/pry-alias) - alias binding.pry to bp (Save on typing)

`group :development`

3. [`gem 'better_errors'`](https://github.com/BetterErrors/better_errors) - better and more useful error page

### 3. Add security and analysis gems

`group :development, :test`

1. [`gem 'brakeman'`](https://github.com/presidentbeef/brakeman) - is a static analysis tool which checks Ruby on Rails applications for security vulnerabilities.
2. [`gem 'bullet'`](https://github.com/flyerhzm/bullet) - Helps you increase your application's performance by reducing the number of queries it makes.
4. [Rubocop](https://github.com/rubocop-hq/rubocop) Linter - Because development environment is based on docker, it is neccesary to install a [Rubocop IDE plugin](https://marketplace.visualstudio.com/items?itemName=misogi.ruby-rubocop)
5. [`gem 'guard'`](https://github.com/guard/guard) Automation - keep watch on your project files and perform actions when they change
6. [`gem 'guard-bundler'`](https://github.com/guard/guard-bundler) - run `bundle install` on changes to the `Gemfile`
7. [`gem 'guard-brakeman'`](https://github.com/guard/guard-brakeman) - automatically run brakeman checks
8. [`gem 'bundler-audit'`](https://github.com/rubysec/bundler-audit) - check Gemlock file for vunerabilities

### 3. Add testing gems
`group :development, :test`

1. [`gem 'factory_bot_rails'`](https://github.com/thoughtbot/factory_bot_rails) - generate and use factories instead of fixtures

`group :test`

2. [`gem 'simplecov', require: false`](https://github.com/colszowka/simplecov) - Code coverage
3. [`gem 'vcr'`](https://github.com/vcr/vcr) - record and replay network calls, for faster and deterministic tests.
4. [`gem 'minitest-vcr'`](https://github.com/mfpiccolo/minitest-vcr) - Integrate minitest into vcr
5. [`gem 'minitest-reporters'`](https://github.com/kern/minitest-reporters) - provides reporters(formatters) for minitest output and can be used to create custom formats
6. [`gem 'guard-minitest'`](https://github.com/guard/guard-minitest) - run test suite when files change
7. [`gem 'webmock'`](https://github.com/bblimke/webmock) - mocked http calls
8. [`gem 'faker'`](https://github.com/faker-ruby/faker) - generate fake, realistic data for your tests
9. [`gem 'timecop'`](https://github.com/travisjeffery/timecop) - pause and move back or forward in time. Useful for tests that are time dependent, e.g check that a key expires when it's supposed to
10. [`gem 'mocha'`](https://github.com/freerange/mocha) - create mock objects and stubs for your unit tests
11. [`gem 'database_cleaner'`](https://github.com/DatabaseCleaner/database_cleaner)
12. [`gem 'rubocop'`](https://github.com/rubocop-hq/rubocop)
13. [`gem 'rubocop-rails', require: false`](https://github.com/rubocop-hq/rubocop-rails) - automatically run rubocop. In test because environment is docker based and will only be used to run rubocop tests.
14. [`gem 'guard-rubocop'`](https://github.com/yujinakayama/guard-rubocop) - check ruby code style on file save

```rb
# Gemfile
# ...
# gem 'mongoid', '~> 7.0.5' # for mongo

gem 'pry-rails'
gem 'awesome_print'

group :development, :test do
  gem 'pry-byebug'
  gem 'pry-alias'
  gem 'better_errors'
  gem 'brakeman'
  gem 'bullet'
  gem 'factory_bot_rails'
  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-brakeman'
end

group :development do
  gem 'better_errors'
end

group :test do
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'minitest-vcr'
  gem 'minitest-reporters'
  gem 'guard-minitest'
  gem 'webmock'
  gem 'faker'
  gem 'timecop'
  gem 'mocha'
  gem 'database_cleaner'
  gem 'rubocop'
  gem 'rubocop-rails', require: false
  gem 'guard-rubocop'
end
```

Update the Gemfile to reflect the above, making any necessary changes. Dont forget to run either of the following after adding gems

```sh
docker-compose run --rm <rails-service> bundle install
docker-compose run --rm <rails-service> bundle update
```

## Gem Configurations

### 1. Configure `pry-rails`, `pry-byebug` and `pry-alias`

The pry console startup configs are read from `.pryrc`, in the project root or `~/`.

```ruby
# .pryrc
# Show red environment name in pry prompt for non development environments
unless Rails.env.development?
  old_prompt = Pry.config.prompt
  env = Pry::Helpers::Text.red(Rails.env.upcase)
  Pry.config.prompt = [
    proc { |*a| "#{env} #{old_prompt.first.call(*a)}" },
    proc { |*a| "#{env} #{old_prompt.second.call(*a)}" }
  ]
end

# don't use less - needed to run pry in a guard session
Pry.config.pager = false

if defined?(PryByebug)
  Pry.commands.alias_command 'c', 'continue'
  Pry.commands.alias_command 's', 'step'
  Pry.commands.alias_command 'n', 'next'
  Pry.commands.alias_command 'f', 'finish'
end

# # Hit Enter to repeat last command
# Pry::Commands.command /^$/, 'repeat last command' do
#   _pry_.run_command Pry.history.to_a.last
# end
```

### 2. Bullet

Bullet won't do ANYTHING unless you tell it to explicitly. Append to `config/environments/development.rb` and `config/environments/test.rb` initializer with the following code:

```rb
# config/environments/test.rb & config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.sentry = true # Sentry.io logging
  Bullet.rails_logger = true
end
```
[Other Bullet Configuraton here](https://github.com/flyerhzm/bullet)

### 3. Configure Guard

To generate a new `Guardfile` with related plugins:

```bash
docker-compose exec rails  guard init
# or to setup specific guards
docker-compose exec rails  guard init bundler rubocop minitest
```

Edit the `Guardfile` at `:minitest` section to un-comment out the `# Rails 4` lines, and comment the `# with Minitest::Unit` section.

Guard runs the _guards_ in the order they appear in the Guardfile. Re-arrange as needed.
e.g you'll normally want to run bundler before running tests.
To run guard;

```bash
docker-compose exec rails  guard
```

### 4. Configure testing gems

To make the testing gems available to the rails test suite, we require them in `test/test_helper.rb`. We configure simplecov, vcr, minitest and remove fixtures. VCR is on by default. To disable set `ENABLE_VCR=false` in `docker-compose.yaml`.

```rb
# test/test_helper.rb
# coverage
require 'simplecov'
SimpleCov.start 'rails'

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# :test gems includes
require 'vcr'
require 'minitest-vcr'
require 'minitest/reporters'
require 'webmock'
require 'faker'
require 'timecop'
require 'mocha/minitest'
require 'database_cleaner'
require 'rubocop'
require 'rubocop-rails'

# ENV['ENABLE_VCR'] = 'false' # To disable VCR
VCR.configure do |config|
  config.allow_http_connections_when_no_cassette = false
  config.cassette_library_dir = File.expand_path('cassettes', __dir__)
  config.hook_into :webmock
  config.ignore_request { ENV['ENABLE_VCR']=='false' }
  config.ignore_localhost = true
  config.default_cassette_options = {
    record: :new_episodes
  }
end
MinitestVcr::Spec.configure!

# use the spec reporter with minitest backtrace filters
Minitest::Reporters.use!(
  Minitest::Reporters::SpecReporter.new,
  ENV,
  Minitest.backtrace_filter
)
...
```

### 3. Configure Rubocop

Create the `.rubocop.yml` file with the following rails cops
```yaml
# .rubocop.yml
require:
  - rubocop-rails

AllCops:
  NewCops: enable

Bundler/OrderedGems:
  Enabled: false

Style/Documentation:
  Enabled: false

Style/ClassAndModuleChildren:
  Exclude:
    - 'test/**/*'

Layout:
  Exclude:
    - 'db/migrate/schema.rb'

Style:
  Exclude:
    - 'db/migrate/schema.rb'

Metrics:
  Exclude:
    - 'db/migrate/schema.rb'

Layout/LineLength:
  # Max: 80
  Exclude:
    - Gemfile
    - Guardfile
    - Rakefile
    - 'config/**/*'
    - 'db/**/*'

Metrics/BlockLength:
  Exclude:
    - 'config/environments/*'
    - 'db/**/*'

Metrics/MethodLength:
  Exclude:
    - 'db/**/*'

Metrics/AbcSize:
  Exclude:
    - 'db/**/*'
```

Run `rubocop --auto-correct` to correct any issues in the generated project;

```sh
docker-compose exec rails  rubocop -a
```

Generate a `.rubocop_todo.yml` file. This file is automatically included in `.rubocop.yml` and lists offenses you will need to resolve manually.

```sh
docker-compose exec rails  rubocop --auto-gen-config
```
Using default [rubocop cops](https://rubocop.readthedocs.io/en/latest/) and [rails cops](https://github.com/rubocop-hq/rubocop-rails#the-cops) definitions work through correcting offenses by
1. Comment out app layout cops on `.rubocop_todo.yml` and start by running layout cops only and correct offenses. Once corrected, delete layout cops from `.rubocop_todo.yml`.

    ```
    docker-compose exec rails  rubocop -x
    ```
2. Run other cop and correct offenses

    ```
    docker-compose exec rails  rubocop
    ```
    Delete cops where you resolve and correct till you have anempty `.rubocop_todo.yml` file

If you IDE rubocop linter is configured well, it will also use the The IDE will also use `.rubocop_todo.yml` files for your linting.

**Setup Faster rubocop for docker**
We setup [rubocop-daemon](https://github.com/fohte/rubocop-daemon) in order to ensure that our linting is fast. On Mac, rubocop is pretty slow, especially on Vscode. This is added to the `dev.Dockerfile`. This ensure running `rubocop` in the container will use the bin script and daemonize.

**Setup Faster rubocop for Vscode**
Install rubocop locally for vscode. This will work with the ruby language service extension.

```
# which rubocop is rbenv running?
$ rbenv which rubocop
<HOME>/.rbenv/versions/x.y.z/bin/rubocop

# Override rubocop with a symlink to rubocop-daemon-wrapper
ln -fs /usr/local/bin/rubocop-daemon-wrapper/rubocop $HOME/.rbenv/versions/x.y.z/bin/rubocop
ln -fs /usr/local/bin/rubocop-daemon-wrapper/rubocop /Users/kariuki/.rbenv/versions/3.0.0/bin/rubocop
```

**rubocop upgrade**
When upgrading the rubocop gem and related(e.g. rubocop-rails), ensure you refresh cache by deleting the rubocop-daemon and rubocop_cache cache folder for the files to link to the proper, newer rubocop version.

```sh
gem update rubocop rubocop-rails

rm -rf ~/.cache/rubocop-daemon
rm -rf ~/.cache/rubocop_cache
```
### 5. Configure root
We'd like to have a default response to the api that's apart from rails default page. add the following to the routes

```rb
# routes.rb
  get '/', to: ->(_) { [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok' }.to_json]] }
```

This will have the root respond with

```json
{ "status": "ok" }
```
## Note

Whenever `bundle` or `bundle install` is run via `docker-compose` or within the container or via `guard-bundler`, the bundler cache is persisted in the volumes to minimizes the need to rebuild the image.

Remember to rebuild the docker image when packaging or deploying and make sure to build with `./Dockerfile` for production and not `./.dev/dev.Dockerfile` used during development

# MacOS Development

For macOS users, file syncing between the host and the container is quite slow due ot OSXFS file system. So we use [docker-sync](https://docker-sync.readthedocs.io/en/latest/getting-started/configuration.html) to [speed](https://dev.to/kovah/cut-your-docker-for-mac-response-times-in-half-with-docker-sync-1e8j) things up while developing. This means every docker-compose command will be substituted by the docker-sync commands

```bash
# Install docker-sync
gem install docker-sync
# start docker sync
docker-sync start
#
# wait until the command finishes creating the volume,  then start app services with mount overrides defined in  docker-compose-dev.yaml:
docker-compose -f docker-compose.yml -f  docker-compose-dev.yml up -d
```

The following aliases come in handy

```bash
# Docker sync
alias dsup="docker-compose -f docker-compose.yaml -f  docker-compose-dev.yaml up"
alias dsdown="docker-compose -f docker-compose.yaml -f  docker-compose-dev.yaml down"
alias dss="docker-sync-stack"
alias ds="docker-sync"
alias sup="ds start && dsup" # Stack Up
alias sdown="dsdown && ds stop" # Stack Down
```

So we replace `docker-compose up -d` with `sup -d`

# Gitlab CI/CD

A `.gitlab-ci.yml` file configures a pipeline intended to be run on gitlab.com. Rename `.gitlab-ci..example.yml` to `.gitlab-ci.yml`

It will [build and push](https://docs.gitlab.com/ee/user/packages/container_registry/index.html#build-and-push-images-using-gitlab-cicd) images to the gitlab container registry associated with your repo.
The file has 4 stages; build, test, release and deploy.
By default build and test stages will be run for the master and release branches.
The release and deploy stages will run only on the release branch.
Configure when these stages are run by updating or removing the `only:` key;

```yaml
only:
  - master
  - release
```

The pipeline is as follows:

1. The build stage will build the docker image and push it to your registry tagged as the value of the `TEST_IMAGE` variable.
2. The test stage will run your test suite against the image built in the build stage
3. The release stage will tag the `TEST_IMAGE` with the `RELEASE_IMAGE` variable and push it to the registry. Update the `VERSION` variable if you wish to keep the previous version of your image
4. The deploy stage should be configured to push the newly tagged `RELEASE_IMAGE` to your staging/production environments. The default configuration assumes deployment to gke and uses an image with the necessary gcloud sdks

> Build \$TEST_IMAGE ---> TEST_IMAGE Test ---> Tag TEST_IMAGE:RELEASE_IMAGE --->Push RELEASE_IMAGE

Refer to the [gitlab CI reference](https://docs.gitlab.com/ee/ci/yaml/README.html) on how to further customize the CI/CD process.

## CI CD variables
The GITLAB_SERVICE_ACCOUNT is needed as a file variable in your gitlab pipeline. Create a gcloud service account with kubernetes developer permissions(can run kubectl commands onk8 cluster). THen update gitlab variables on the gitlab settings dashboard. Also update the following `.gitlab-ci.yaml` variables as well

```yaml
ZONE: "europe-west6-a"
CLOUDSDK_CORE_PROJECT: "project-name"
CLUSTER_NAME: "cluster-name"
```
## Heroku Deployment with Docker and Gitlab CI
### Pre-requisites:
- Heroku Account
- Heroku CLI
- Heroku Auth Token - obtained using `heroku auth:token` CLI command

Then, create a new app,

```bash
heroku create
```

Then, login to the heroku container registry,

```bash
heroku container:login
```

Build the image and tag it as `registry.heroku.com/{heroku-app-name}>/web`

We are using web at the end of the image tag to state the type of heroku dyno we need.

```bash
docker build -t registry.heroku.com/your-heroku-app-name/web .
```

Push the image to the registry,

```bash
docker push registry.heroku.com/your-heroku-app-name/web
```

Create the rails ENV variables for your rails app. However, leave out `DATABASE_URL` and `REDIS_URL` since they'll be automatically created during provisioning of Heroku-Postgresql and Heroku-Redis on Heroku.

Read on [Heroku-Postgresql](https://devcenter.heroku.com/articles/heroku-postgresql) and [Heroku-Redis](https://devcenter.heroku.com/articles/heroku-redis) provisioning.

Then, Release the image,

```bash
heroku container:release web -a your-heroku-app-name
```

Heroku will deploy the image afterwhich you can visit your app by following https://your-heroku-app-name.heroku.com

### Continuos deployment with GitLab CI
Retrieve a heroku auth token and save it as a variable using name `HEROKU_TOKEN` in gitlab CI under Settings > CI / CD > Variables.

Then, your staging deployment job should be similar to the `deploy-staging` job in `.gitlab-ci.example.yml`

Make a quick change to your app, push changes to gitlab and watch Gitlab building and deploying your new updates automatically.
