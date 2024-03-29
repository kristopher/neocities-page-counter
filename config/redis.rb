require 'redis'

RedisConfig = {}

class Redis
  def self.current
    @current ||= Redis.new(RedisConfig)
  end
end

if %(production).include?(ENV['RACK_ENV'])
  RedisConfig[:url] = ENV["REDISCLOUD_URL"]
else
  RedisConfig[:host] = 'localhost'
end

Redis.current

