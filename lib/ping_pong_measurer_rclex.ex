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
    start_ping_processes(pong_node_count, ping_pub, ping_sub, payload_size, 1000)
    start_measurer_process(pong_node_count, ping_pub, ping_sub, payload_size)

    OsInfoMeasurer.start(
      "data/rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}_#{payload_size}",
      "rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}_#{payload_size}_",
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

  def start_ping_side_processes(
        pong_node_count,
        ping_pub,
        ping_sub,
        payload_size,
        measurement_times \\ 100,
        disable_os_info_measuring \\ true
      ) do
    start_ping_processes(pong_node_count, ping_pub, ping_sub, payload_size, measurement_times)
    # NOTE: Publisher が初発を送るために待つ必要がある。
    #       原因不明、 https://github.com/rclex/rclex/issues/212 の可能性がある。
    Process.sleep(100)

    # RTT 計測時に OS 情報計測は不要、 OS 情報計測時に RTT 計測は不要
    if disable_os_info_measuring do
      start_measurer_process(pong_node_count, ping_pub, ping_sub, payload_size)
    else
      # OS 情報を 1s 余分に計測
      OsInfoMeasurer.start(
        "data/rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}_#{payload_size}",
        "rclex_#{String.pad_leading("#{pong_node_count}", 3, "0")}_#{ping_pub}_#{ping_sub}_#{payload_size}_",
        100
      )

      Process.sleep(1000)
    end

    :ok = Ping.start_measuring()

    receive do
      :end -> :do_nothing
    end

    GenServer.stop(Ping)

    if disable_os_info_measuring do
      GenServer.stop(Measurer)
    else
      # OS 情報を 1s 余分に計測
      Process.sleep(1000)

      OsInfoMeasurer.stop()
    end

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
  def start_ping_processes(pong_node_count, pub, sub, payload_size, measurement_times \\ 100) do
    Ping.start_link(
      pong_node_count: pong_node_count,
      pub: pub,
      sub: sub,
      payload_size: payload_size,
      measurement_times: measurement_times
    )
  end

  def start_measurer_process(pong_node_count, pub, sub, payload_size) do
    Measurer.start_link(
      pong_node_count: pong_node_count,
      pub: pub,
      sub: sub,
      payload_size: payload_size
    )
  end
end
