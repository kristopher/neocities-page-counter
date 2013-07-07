require 'pusher'

if ENV['RACK_ENV'] == 'development'
  Pusher.app_id = '48822'
  Pusher.key    = '4e59bb6615620256204d'
  Pusher.secret = 'efd731ec2ff75ded68ff'
end