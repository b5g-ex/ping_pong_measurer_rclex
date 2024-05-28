defmodule PingPongMeasurerRclex.Starter do
  use GenServer

  alias Rclex.Pkgs.StdMsgs

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_measurement() do
    GenServer.call(__MODULE__, :start_measurement)
  end

  def init(_args) do
    node_name = "starter"
    :ok = Rclex.start_node(node_name)

    topic_name = "/from_starter"
    :ok = Rclex.start_publisher(StdMsgs.Msg.String, topic_name, node_name)

    me = self()

    :ok =
      Rclex.start_subscription(
        fn
          _message = %{data: "a measurement completed"} ->
            send(me, :start_measurement)

          _message = %{data: "measurements completed"} ->
            send(me, :send_end)
        end,
        StdMsgs.Msg.String,
        "/from_ping_to_starter",
        node_name
      )

    {:ok, %{topic_name: topic_name, node_name: node_name, caller: nil}}
  end

  def handle_call(:start_measurement, _from = {pid, _tag}, state) do
    start_measurement(state.topic_name, state.node_name)
    {:reply, :ok, %{state | caller: pid}}
  end

  def handle_info(:start_measurement, state) do
    start_measurement(state.topic_name, state.node_name)
    {:noreply, state}
  end

  def handle_info(:send_end, state) do
    send(state.caller, :end)
    {:noreply, state}
  end

  defp start_measurement(topic_name, node_name) do
    publish_impl("start", topic_name, node_name)
  end

  defp publish_impl(data, topic_name, node_name) do
    Rclex.publish(
      struct(StdMsgs.Msg.String, %{data: data}),
      topic_name,
      node_name
    )
  end
end
