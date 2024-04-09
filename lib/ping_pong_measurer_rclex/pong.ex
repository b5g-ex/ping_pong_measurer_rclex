defmodule PingPongMeasurerRclex.Pong do
  use GenServer

  alias Rclex.Pkgs.StdMsgs

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    Process.flag(:trap_exit, true)

    node_count = Keyword.fetch!(args, :node_count)
    ping_pub = Keyword.fetch!(args, :ping_pub)
    ping_sub = Keyword.fetch!(args, :ping_sub)

    node_names =
      for index <- 0..(node_count - 1) do
        node_name = "pong" <> String.pad_leading("#{index}", 3, "0")

        :ok = Rclex.start_node(node_name)
        node_name
      end

    for {node_name, index} <- Enum.with_index(node_names) do
      ping_topic =
        case ping_pub do
          :single -> "/ping000"
          :multiple -> "/ping" <> String.pad_leading("#{index}", 3, "0")
        end

      pong_topic =
        case ping_sub do
          :single -> "/pong000"
          :multiple -> "/pong" <> String.pad_leading("#{index}", 3, "0")
        end

      :ok =
        Rclex.start_subscription(
          &Rclex.publish(&1, pong_topic, node_name),
          StdMsgs.Msg.String,
          ping_topic,
          node_name
        )

      :ok = Rclex.start_publisher(StdMsgs.Msg.String, pong_topic, node_name)
    end

    {:ok, %{node_count: node_count, node_names: node_names}}
  end

  def terminate(:normal, state) do
    for node_name <- state.node_names do
      Rclex.stop_node(node_name)
    end
  end
end
