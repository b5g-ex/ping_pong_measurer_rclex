defmodule PingPongMeasurerRclex do
  @moduledoc """
  Documentation for `PingPongMeasurerRclex`.
  """

  require Logger

  alias PingPongMeasurerRclex.Pong
  alias PingPongMeasurerRclex.Ping
  alias PingPongMeasurerRclex.Measurer

  def local_test(pong_node_count, ping_pub, ping_sub, payload_size) do
    start_pong_processes(pong_node_count, ping_pub, ping_sub)
    start_ping_processes(pong_node_count, ping_pub, ping_sub, payload_size)
    start_measurer_process(pong_node_count, ping_pub, ping_sub)

    OsInfoMeasurer.start(
      "data/rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}",
      "rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}_",
      100
    )

    Process.sleep(1000)
    Ping.start_measuring()

    receive do
      :end -> :do_nothing
    end

    GenServer.stop(Pong)
    GenServer.stop(Ping)
    GenServer.stop(Measurer)

    Process.sleep(1000)
    OsInfoMeasurer.stop()
    Logger.info("THE END")
  end

  def start_ping_side_processes(pong_node_count, ping_pub, ping_sub, payload_size) do
    start_ping_processes(pong_node_count, ping_pub, ping_sub, payload_size)
    start_measurer_process(pong_node_count, ping_pub, ping_sub)

    # OS 情報を 1s 余分に計測
    OsInfoMeasurer.start(
      "data/rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}",
      "rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}_",
      10
    )

    Process.sleep(1000)

    Ping.start_measuring()

    receive do
      :end -> :do_nothing
    end

    GenServer.stop(Ping)
    GenServer.stop(Measurer)

    # OS 情報を 1s 余分に計測
    Process.sleep(1000)
    OsInfoMeasurer.stop()
    Logger.info("THE END")
  end

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

  def stop_pong_processes() do
    GenServer.stop(Pong)
  end

  @doc """
  ## Examples
      iex> start_ping_processes(10, :single, :single, 8)
      iex> start_ping_processes(10, :multiple, :single, 8)
      iex> start_ping_processes(10, :single, :multiple, 8)
      iex> start_ping_processes(10, :multiple, :multiple, 8)
  """
  def start_ping_processes(pong_node_count, pub, sub, payload_size) do
    Ping.start_link(
      pong_node_count: pong_node_count,
      pub: pub,
      sub: sub,
      payload_size: payload_size
    )
  end

  def start_measurer_process(pong_node_count, pub, sub) do
    Measurer.start_link(pong_node_count: pong_node_count, pub: pub, sub: sub)
  end
end
