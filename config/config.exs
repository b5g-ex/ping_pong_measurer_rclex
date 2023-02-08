import Config

config :logger, level: :info

config :ping_pong_measurer_rclex, :data_directory_path, "./data"

config :rclex, ros2_message_types: ["std_msgs/msg/String"]
