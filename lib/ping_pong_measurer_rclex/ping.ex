defmodule PingPongMeasurerRclex.Ping do
  use GenServer

  alias Rclex.Pkgs.StdMsgs

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    pong_node_count = Keyword.fetch!(args, :pong_node_count)
    pub = Keyword.fetch!(args, :pub)
    sub = Keyword.fetch!(args, :sub)

    node_name = "ping"
    :ok = Rclex.start_node(node_name)

    case pub do
      :single ->
        ping_topic = "/ping"
        :ok = Rclex.start_publisher(StdMsgs.Msg.String, ping_topic, node_name)

      :multiple ->
        for index <- 0..(pong_node_count - 1) do
          ping_topic = "/ping" <> String.pad_leading("#{index}", 3, "0")
          :ok = Rclex.start_publisher(StdMsgs.Msg.String, ping_topic, node_name)
        end
    end

    case sub do
      :single ->
        pong_topic = "/pong"
        :ok = Rclex.start_subscription(fn _ -> nil end, StdMsgs.Msg.String, pong_topic, node_name)

      :multiple ->
        for index <- 0..(pong_node_count - 1) do
          pong_topic = "/pong" <> String.pad_leading("#{index}", 3, "0")

          :ok =
            Rclex.start_subscription(fn _ -> nil end, StdMsgs.Msg.String, pong_topic, node_name)
        end
    end

    {:ok, %{pong_node_count: pong_node_count}}
  end
end
