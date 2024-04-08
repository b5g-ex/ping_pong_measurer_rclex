defmodule PingPongMeasurerRclex.Ping do
  use GenServer

  require Logger

  alias PingPongMeasurerRclex.Measurer
  alias Rclex.Pkgs.StdMsgs

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def node_name() do
    GenServer.call(__MODULE__, :node_name)
  end

  def pong_node_count() do
    GenServer.call(__MODULE__, :pong_node_count)
  end

  def init(args) do
    pong_node_count = Keyword.fetch!(args, :pong_node_count)
    pub = Keyword.fetch!(args, :pub)
    sub = Keyword.fetch!(args, :sub)

    node_name = "ping"
    :ok = Rclex.start_node(node_name)

    case pub do
      :single ->
        ping_topic = "/ping000"
        :ok = Rclex.start_publisher(StdMsgs.Msg.String, ping_topic, node_name)

      :multiple ->
        for index <- 0..(pong_node_count - 1) do
          ping_topic = "/ping" <> String.pad_leading("#{index}", 3, "0")
          :ok = Rclex.start_publisher(StdMsgs.Msg.String, ping_topic, node_name)
        end
    end

    callback = fn message ->
      # ここで計測終了
      time = System.monotonic_time(:microsecond)
      Measurer.stop_measuring(time, _index = String.slice(message.data, 0, 3))
      Logger.debug("ping recv: #{inspect(message)}")
    end

    case sub do
      :single ->
        pong_topic = "/pong000"
        :ok = Rclex.start_subscription(callback, StdMsgs.Msg.String, pong_topic, node_name)

      :multiple ->
        for index <- 0..(pong_node_count - 1) do
          pong_topic = "/pong" <> String.pad_leading("#{index}", 3, "0")

          :ok =
            Rclex.start_subscription(callback, StdMsgs.Msg.String, pong_topic, node_name)
        end
    end

    {:ok, %{pong_node_count: pong_node_count, node_name: node_name}}
  end

  def handle_call(:node_name, _from, state) do
    {:reply, state.node_name, state}
  end

  def handle_call(:pong_node_count, _from, state) do
    {:reply, state.pong_node_count, state}
  end
end
