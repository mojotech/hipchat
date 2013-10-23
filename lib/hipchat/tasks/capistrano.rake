require 'hipchat'
require 'pry'

set :hipchat_send_notification, false
set :hipchat_with_migrations, false

namespace :hipchat do
  task :set_client do
    set :hipchat_client, HipChat::Client.new(fetch(:hipchat_token))
  end

  task :trigger_notification do
    set :hipchat_send_notification, true
  end

  task :configure_for_migrations do
    set :hipchat_with_migrations, true
  end

  task :notify_deploy_started do
    if fetch(:hipchat_send_notification)
      before "deploy:rollback", "notify_rollback_started" do
        on roles(:app) do
          send_options.merge!(:color => failed_message_color)
          hipchat_client[fetch(:hipchat_room_name)].
            send(deploy_user, "#{human} cancelled deployment of #{deployment_name} to #{environment}.", send_options)
        end
      end

      message = "#{human} is deploying #{deployment_name} to #{environment}"
      message << " (with migrations)" if fetch(:hipchat_with_migrations)
      message << "."

      hipchat_client[fetch(:hipchat_room_name)].send(deploy_user, message, send_options)
    end
  end

  task :notify_deploy_finished do
    hipchat_client[fetch(:hipchat_room_name)].
      send(deploy_user, "#{human} finished deploying #{deployment_name} to #{environment}.", send_options)
  end

  def hipchat_client
    fetch(:hipchat_client)
  end

  def send_options
    return @send_options if defined?(@send_options)
    @send_options = message_color ? {:color => message_color} : {}
    @send_options.merge!(:notify => message_notification)
    @send_options
  end

  def deployment_name
    if fetch(:branch)
      "#{fetch(:application)}/#{fetch(:branch)}"
    else
      fetch(:application)
    end
  end

  def message_color
    fetch(:hipchat_color, nil)
  end

  def failed_message_color
    fetch(:hipchat_failed_color, "red")
  end

  def message_notification
    fetch(:hipchat_announce, false)
  end

  def deploy_user
    fetch(:hipchat_deploy_user, "Deploy")
  end

  def human
    ENV['HIPCHAT_USER'] ||
      fetch(:hipchat_human,
            if (u = %x{git config user.name}.strip) != ""
              u
            elsif (u = ENV['USER']) != ""
              u
            else
              "Someone"
            end)
  end

  def environment
    fetch(:hipchat_env, fetch(:rack_env, fetch(:rails_env, "production")))
  end
end

before "hipchat:notify_deploy_started", "hipchat:set_client"
before "deploy:starting", "hipchat:trigger_notification"
before "deploy:starting", "hipchat:notify_deploy_started"
before "deploy:migrate", "hipchat:trigger_notification", "hipchat:configure_for_migrations"
after  "deploy:migrate", "hipchat:notify_deploy_finished"
after  "deploy:finished", "hipchat:notify_deploy_finished"
