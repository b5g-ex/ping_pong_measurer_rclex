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
      iex> start_measuring()
  """
  def start_measuring() do
    GenServer.call(__MODULE__, :start_measuring)
  end

  def init(args) do
    Process.flag(:trap_exit, true)

    pong_node_count = Keyword.fetch!(args, :pong_node_count)
    pub = Keyword.fetch!(args, :pub)
    sub = Keyword.fetch!(args, :sub)
    payload_size = Keyword.fetch!(args, :payload_size)

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

    me = self()

    callback = fn message ->
      # ここで計測終了
      time = System.monotonic_time(:microsecond)
      Measurer.stop_measuring(time, _index = String.slice(message.data, 0, 3))
      send(me, :pong_received)
    end

    case sub do
      :single ->
        pong_topic = "/pong000"

        :ok =
          Rclex.start_subscription(callback, StdMsgs.Msg.String, pong_topic, node_name,
            qos: %Rclex.QoS{depth: 100}
          )

      :multiple ->
        for index <- 0..(pong_node_count - 1) do
          pong_topic = "/pong" <> String.pad_leading("#{index}", 3, "0")

          :ok =
            Rclex.start_subscription(callback, StdMsgs.Msg.String, pong_topic, node_name)
        end
    end

    {:ok,
     %{
       pong_node_count: pong_node_count,
       pub: pub,
       sub: sub,
       node_name: node_name,
       pong_received_count: 0,
       ping_sent_count: 0,
       payload_size: payload_size,
       starter: nil
     }}
  end

  def terminate(:normal, state) do
    Rclex.stop_node(state.node_name)
  end

  def handle_call(:start_measuring, _from = {pid, _tag}, state) do
    start_measuring(state)
    {:reply, :ok, %{state | starter: pid}}
  end

  def handle_info(:pong_received, state) do
    pong_received_count = state.pong_received_count + 1
    # Logger.info("#{pong_received_count}/#{state.pong_node_count}")

    if pong_received_count < state.pong_node_count do
      {:noreply, %{state | pong_received_count: pong_received_count}}
    else
      ping_sent_count = state.ping_sent_count + 1

      if ping_sent_count < 100 do
        Logger.info("GO NEXT: #{ping_sent_count}")
        start_measuring(state)
        {:noreply, %{state | pong_received_count: 0, ping_sent_count: ping_sent_count}}
      else
        Logger.info("THE END: #{ping_sent_count}")
        send(state.starter, :end)
        {:noreply, %{state | pong_received_count: 0, ping_sent_count: 0}}
      end
    end
  end

  def handle_info({:EXIT, _pid, :normal}, state) do
    # NOTE: Process.flag(:trap_exit, true) すると Flow の EXIT のハンドリングが必要になる。
    # TODO: Flow から EXIT が飛んでくる原理を理解すること
    {:noreply, state}
  end

  defp start_measuring(state) do
    case state.pub do
      :single ->
        ping_topic = "/ping000"
        # ここで計測開始
        index = String.slice(ping_topic, 5, 3)
        payload = String.duplicate("0", state.payload_size)
        if state.payload_size != byte_size(payload), do: raise(RuntimeError)
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
          payload = String.duplicate("0", state.payload_size)
          if state.payload_size != byte_size(payload), do: raise(RuntimeError)
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
  end
end
