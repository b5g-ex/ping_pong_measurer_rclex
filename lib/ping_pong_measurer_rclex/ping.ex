defmodule PingPongMeasurerRclex.Ping do
  use GenServer

  require Logger

  alias PingPongMeasurerRclex.Measurer
  alias Rclex.Pkgs.StdMsgs

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  ## Examples
      iex> start_measuring(8)
  """
  def start_measuring(payload_size) do
    GenServer.call(__MODULE__, {:start_measuring, payload_size})
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

    {:ok, %{pong_node_count: pong_node_count, pub: pub, sub: sub, node_name: node_name}}
  end

  def handle_call({:start_measuring, payload_size}, _from, state) do
    case state.pub do
      :single ->
        ping_topic = "/ping000"
        # ここで計測開始
        index = String.slice(ping_topic, 5, 3)
        payload = index <> String.duplicate("0", payload_size - String.length(index))
        :ok = Measurer.start_measuring(System.monotonic_time(:microsecond), index)

        :ok =
          Rclex.publish(
            struct(StdMsgs.Msg.String, %{data: payload}),
            ping_topic,
            state.node_name
          )

      :multiple ->
        ping_topics =
          for index <- 0..(state.pong_node_count - 1) do
            "/ping" <> String.pad_leading("#{index}", 3, "0")
          end

        ping_topics
        |> Flow.from_enumerable(max_demand: 1, stages: state.pong_node_count)
        |> Flow.map(fn ping_topic ->
          # ここで計測開始
          index = String.slice(ping_topic, 5, 3)
          payload = index <> String.duplicate("0", payload_size - String.length(index))
          :ok = Measurer.start_measuring(System.monotonic_time(:microsecond), index)

          :ok =
            Rclex.publish(
              struct(StdMsgs.Msg.String, %{data: payload}),
              ping_topic,
              state.node_name
            )
        end)
        |> Enum.to_list()
    end

    {:reply, :ok, state}
  end
end
