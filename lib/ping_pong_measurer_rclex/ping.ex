defmodule PingPongMeasurerRclex.Ping do
  use GenServer

  require Logger

  alias PingPongMeasurerRclex.Measurer
  alias Rclex.Pkgs.StdMsgs

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    Process.flag(:trap_exit, true)

    pong_node_count = Keyword.fetch!(args, :pong_node_count)
    pub = Keyword.fetch!(args, :pub)
    sub = Keyword.fetch!(args, :sub)
    payload_size = Keyword.fetch!(args, :payload_size)
    measurement_times = Keyword.fetch!(args, :measurement_times)

    node_name = "ping000"
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
      time = time(:microsecond)
      index = binary_part(message.data, 0, 3)
      Measurer.stop_measuring(time, index)
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

    :ok = Rclex.start_publisher(StdMsgs.Msg.String, "/from_ping_to_starter", node_name)

    :ok =
      Rclex.start_subscription(
        fn _message = %{data: "start"} -> send(me, :ping) end,
        StdMsgs.Msg.String,
        "/from_starter",
        node_name
      )

    {:ok,
     %{
       pong_node_count: pong_node_count,
       pub: pub,
       sub: sub,
       node_name: node_name,
       pong_received_count: 0,
       measurement_count: 0,
       payload_size: payload_size,
       measurement_times: measurement_times
     }}
  end

  def terminate(:normal, state) do
    Rclex.stop_node(state.node_name)
  end

  def handle_info(:ping, state) do
    ping(state)
    {:noreply, state}
  end

  def handle_info(:pong_received, state) do
    pong_received_count = state.pong_received_count + 1
    # Logger.info("#{pong_received_count}/#{state.pong_node_count}")

    if pong_received_count < state.pong_node_count do
      {:noreply, %{state | pong_received_count: pong_received_count}}
    else
      measurement_count = state.measurement_count + 1

      if measurement_count < state.measurement_times do
        Logger.info("GO NEXT: #{measurement_count}/#{state.measurement_times}")

        Rclex.publish(
          struct(StdMsgs.Msg.String, %{data: "a measurement completed"}),
          "/from_ping_to_starter",
          state.node_name
        )

        {:noreply, %{state | pong_received_count: 0, measurement_count: measurement_count}}
      else
        Logger.info("THE END: #{measurement_count}/#{state.measurement_times}")

        Rclex.publish(
          struct(StdMsgs.Msg.String, %{data: "measurements completed"}),
          "/from_ping_to_starter",
          state.node_name
        )

        {:noreply, %{state | pong_received_count: 0, measurement_count: 0}}
      end
    end
  end

  def handle_info({:EXIT, _pid, :normal}, state) do
    # NOTE: Process.flag(:trap_exit, true) すると Flow の EXIT のハンドリングが必要になる。
    # TODO: Flow から EXIT が飛んでくる原理を理解すること
    {:noreply, state}
  end

  def handle_info(info = {:EXIT, _pid, :shutdown}, state) do
    # NOTE: Process.flag(:trap_exit, true) すると Flow の EXIT のハンドリングが必要になる。
    # TODO: Flow から EXIT が飛んでくる原理を理解すること
    Logger.info("#{inspect(info)}")
    {:noreply, state}
  end

  defp ping(state) do
    case state.pub do
      :single ->
        ping_topic = "/ping000"
        # ここで計測開始
        index = binary_part(ping_topic, 5, 3)
        payload = String.duplicate("0", state.payload_size)
        if state.payload_size != byte_size(payload), do: raise(RuntimeError)
        :ok = Measurer.start_measuring(time(:microsecond), index)

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
          index = binary_part(ping_topic, 5, 3)
          payload = String.duplicate("0", state.payload_size)
          if state.payload_size != byte_size(payload), do: raise(RuntimeError)
          :ok = Measurer.start_measuring(time(:microsecond), index)

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

  defdelegate time(unit), to: System, as: :os_time
end
