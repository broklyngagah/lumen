# Defines our constants
RACK_ENV = ENV['RACK_ENV'] ||= 'development'  unless defined?(RACK_ENV)
PADRINO_ROOT = File.expand_path('../..', __FILE__) unless defined?(PADRINO_ROOT)
PADRINO_LOGGER = { :production => { :log_level => :info, :stream => :to_file }} if RACK_ENV == 'production'

# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
Bundler.require(:default, RACK_ENV)

require 'net/imap'

Padrino.load!

Mongoid.load!("#{PADRINO_ROOT}/config/mongoid.yml")
Mongoid.raise_not_found_error = false
