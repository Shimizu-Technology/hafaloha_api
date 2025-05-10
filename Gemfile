source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# For CORS handling:
gem "rack-cors", require: "rack/cors"
# Authentication
gem "bcrypt", "~> 3.1.7"
# Authentication
gem "jwt", "~> 2.2"
# Create fake data
gem "faker"
# Allow rails to use the .env file
gem "dotenv-rails"
# Rails background job adapter
gem "sidekiq"
gem "rufus-scheduler", "~> 3.8"
# AWS S3
gem "aws-sdk-s3", require: false
# Pagination
gem "kaminari"
# Payment processing
gem "braintree"
gem "paypal-checkout-sdk"
gem "stripe"
# Web Push notifications
gem "web-push", "~> 3.0.1"
# Analytics
gem "posthog-ruby"
# Monitoring and metrics
gem "prometheus-client"
# Authorization
gem "pundit"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"
# Use Redis adapter for caching and Action Cable in production
gem "redis", ">= 4.0.1"
gem "connection_pool"  # For managing Redis connections

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing gems
  gem "rspec-rails"
  gem "shoulda-matchers"  # For testing ActiveRecord relationships and validations
  gem "factory_bot_rails" # You already have factories but this makes the integration explicit
  # faker is already included in the main gems section
  gem "database_cleaner-active_record" # For cleaning test database between runs
end

group :test do
  gem "simplecov", require: false # For tracking test coverage
  gem "webmock"    # For mocking external API calls
end
