defmodule PingPongMeasurerRclex do
  @moduledoc """
  Documentation for `PingPongMeasurerRclex`.
  """

  alias PingPongMeasurerRclex.Pong
  alias PingPongMeasurerRclex.Ping
  alias Rclex.Pkgs.StdMsgs

  @doc """
  ## Examples
      iex> start_pong_processes(10, :single, :single)
      iex> start_pong_processes(10, :multiple, :single)
      iex> start_pong_processes(10, :single, :multiple)
      iex> start_pong_processes(10, :multiple, :multiple)
  """
  def start_pong_processes(node_count, ping_pub, ping_sub) do
    Pong.start_link(node_count: node_count, ping_pub: ping_pub, ping_sub: ping_sub)
  end

  @doc """
  ## Examples
      iex> start_ping_processes(10, :single, :single)
      iex> start_ping_processes(10, :multiple, :single)
      iex> start_ping_processes(10, :single, :multiple)
      iex> start_ping_processes(10, :multiple, :multiple)
  """
  def start_ping_processes(pong_node_count, pub, sub) do
    Ping.start_link(pong_node_count: pong_node_count, pub: pub, sub: sub)
  end

  @doc """
  ## Examples
      iex> start_measuring(:single, 8)
      iex> start_measuring(:multiple, 8)
  """
  def start_measuring(ping_pub, payload_size) do
    node_name = Ping.node_name()
    payload = String.duplicate("a", payload_size)

    case ping_pub do
      :single ->
        ping_topic = "/ping"
        :ok = Rclex.publish(struct(StdMsgs.Msg.String, %{data: payload}), ping_topic, node_name)

      :multiple ->
        pong_node_count = Ping.pong_node_count()

        ping_topics =
          for index <- 0..(pong_node_count - 1) do
            "/ping" <> String.pad_leading("#{index}", 3, "0")
          end

        ping_topics
        |> Flow.from_enumerable(max_demand: 1, stages: pong_node_count)
        |> Flow.map(fn ping_topic ->
          :ok = Rclex.publish(struct(StdMsgs.Msg.String, %{data: payload}), ping_topic, node_name)
        end)
        |> Enum.to_list()
    end
  end
end
