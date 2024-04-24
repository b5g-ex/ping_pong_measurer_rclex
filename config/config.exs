import Config

config :logger, level: :info

config :rclex, ros2_message_types: ["std_msgs/msg/String"]

config :logger,
  compile_time_purge_matching: [
    [application: :rclex],
    [level_lower_than: :info]
  ]
