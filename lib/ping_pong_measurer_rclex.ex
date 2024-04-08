defmodule PingPongMeasurerRclex do
  @moduledoc """
  Documentation for `PingPongMeasurerRclex`.
  """

  alias PingPongMeasurerRclex.Pong
  alias PingPongMeasurerRclex.Ping
  alias PingPongMeasurerRclex.Measurer

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

  def start_measurer_process(pong_node_count, pub, sub) do
    Measurer.start_link(pong_node_count: pong_node_count, pub: pub, sub: sub)
  end
end
