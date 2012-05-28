require "rack/session/cookie"
require File.expand_path("../lib/myapp", __FILE__)

use Rack::Session::Cookie, :domain => "localhost",
                           :path => "/",
                           :expire_after => 60 * 60 * 24 * 7

run LazyApp.new
