require "faraday"
require "http/cookie_jar"

module Faraday
  class CookieJar < Faraday::Middleware
    def self.filename
      @filename
    end
    def self.filename=(filename)
      @filename = filename
    end
    def self.save_options
      @save_options
    end
    def self.save_options=(save_options)
      @save_options = save_options
    end

    def self.configure(&block)
      yield self
    end

    def initialize(app, options = {})
      super(app)
      @jar = options[:jar] || HTTP::CookieJar.new
    end

    def call(env)
      @jar.load(Faraday::CookieJar.filename) if !Faraday::CookieJar.filename.nil? && File.exist?(Faraday::CookieJar.filename)
      cookies = @jar.cookies(env[:url])
      unless cookies.empty?
        cookie_value = HTTP::Cookie.cookie_value(cookies)
        if env[:request_headers]["Cookie"]
          unless env[:request_headers]["Cookie"] == cookie_value
            env[:request_headers]["Cookie"] = cookie_value + ';' + env[:request_headers]["Cookie"]
          end
        else
          env[:request_headers]["Cookie"] = cookie_value
        end
      end

      @app.call(env).on_complete do |res|
        if res[:response_headers]
          if set_cookie = res[:response_headers]["Set-Cookie"]
            @jar.parse(set_cookie, env[:url])
          end
          FileUtils.mkdir_p(File.dirname(Faraday::CookieJar.filename)) unless Faraday::CookieJar.filename.nil?
          @jar.save(Faraday::CookieJar.filename, Faraday::CookieJar.save_options) unless Faraday::CookieJar.filename.nil?
        end
      end
    end
  end
end

if Faraday::Middleware.respond_to? :register_middleware
  Faraday::Middleware.register_middleware :cookie_jar => Faraday::CookieJar
end
