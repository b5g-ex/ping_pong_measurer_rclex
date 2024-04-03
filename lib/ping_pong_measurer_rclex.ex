defmodule PingPongMeasurerRclex do
  @moduledoc """
  Documentation for `PingPongMeasurerRclex`.
  """

  alias PingPongMeasurerRclex.Pong
  alias PingPongMeasurerRclex.Ping

  def start_pong_processes(node_count, ping_pub, ping_sub) do
    Pong.start_link(node_count: node_count, ping_pub: ping_pub, ping_sub: ping_sub)
  end

  def start_ping_processes(pong_node_count, pub, sub) do
    Ping.start_link(pong_node_count: pong_node_count, pub: pub, sub: sub)
  end
end
