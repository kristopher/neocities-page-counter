require 'cgi'
require 'json'
require 'eventmachine'
require 'em-http-request'
require 'newrelic_rpm'
require 'new_relic/agent/instrumentation/rack'

require './config/redis.rb'
require './config/pusher.rb'

# http://opensoul.org/blog/archives/2011/08/30/pusher-notifications-with-eventmachine/

class Application
  attr_reader :thread

  def self.run_em
    @thread = Thread.new do
      EM.run
    end
  end

  def self.stop_em
    EM::stop_event_loop
  end

  def self.call(env)
    Application.new(env).dispatch
  end

  def initialize(env)
    @env = env
    @request = Rack::Request.new(env)
  end

  def not_found
    [404, {}, []]
  end

  def params
    @request.params
  end

  def referer
    @request.referer || @env['HTTP_REFERER']
  end

  def subdomain
    @subdomain ||=
      if ENV['RACK_ENV'] == 'production'
        if referer && (matches = referer.scan(/http(s)?\:\/\/(.+)\.neocities\.org/i)[0]) && matches[1]
          matches[1]
        end
      else
        if !params['subdomain'].nil? && !params['subdomain'].empty?
          params['subdomain']
        end
      end
  end

  def with_callback(body)
    if params['callback']
      params['callback'] + "(#{body});"
    else
      body
    end
  end

  def dispatch
    unless subdomain
      return not_found
    end

    headers ||= {
      'Content-Type' => 'application/json'
    }

    if ENV['RACK_ENV'] == 'production'
      if @env['HTTP_ORIGIN'] && @env['HTTP_ORIGIN'] =~ /http(s)?\:\/\/.+\.neocities\.org/i
        headers['Access-Control-Allow-Origin'] = @env['HTTP_ORIGIN']
      end
    else
      headers['Access-Control-Allow-Origin'] = '*'
    end

    if @request.get?
      [200, headers, [with_callback(Redis.current.get(subdomain) || 0).to_s]]
    elsif @request.post?
      amount = Redis.current.incr(subdomain);

      Pusher[subdomain].trigger_async('hit', {});

      if params['return_to']
        [302, { 'Location' => params['return_to'] }, []]
      else
        [201, headers, [with_callback(amount.to_s)]]
      end
    else
      [404, {}, []]
    end
  end
end