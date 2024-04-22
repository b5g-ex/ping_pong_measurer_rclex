defmodule PingPongMeasurerRclex.Measurer do
  use GenServer

  require Logger

  defmodule State do
    defstruct pong_node_count: 0, pub: nil, sub: nil, current_measurement: nil, measurements: []
  end

  defmodule Measurement do
    defstruct send_times: [], recv_times: []
    @type t() :: %__MODULE__{send_times: list(), recv_times: list()}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_measuring(time, index) do
    GenServer.cast(__MODULE__, {:start_measuring, time, index})
  end

  def stop_measuring(time, index) do
    GenServer.cast(__MODULE__, {:stop_measuring, time, index})
  end

  def init(args) do
    Process.flag(:trap_exit, true)

    pong_node_count = Keyword.fetch!(args, :pong_node_count)
    pub = Keyword.fetch!(args, :pub)
    sub = Keyword.fetch!(args, :sub)

    {:ok, %State{pong_node_count: pong_node_count, pub: pub, sub: sub}}
  end

  def terminate(:normal, state) do
    file_path =
      "data/rclex_#{String.pad_leading("#{state.pong_node_count}", 3, "0")}_#{state.pub}_#{state.sub}.csv"

    File.mkdir_p!(Path.dirname(file_path))

    save(file_path, [header(state.measurements) | body(state.measurements)])
  end

  def handle_cast({:start_measuring, time, index}, state) do
    current_measurement =
      if is_nil(state.current_measurement) do
        case state.pub do
          :single ->
            %Measurement{
              send_times: List.duplicate(nil, 1),
              recv_times: List.duplicate(nil, state.pong_node_count)
            }

          :multiple ->
            %Measurement{
              send_times: List.duplicate(nil, state.pong_node_count),
              recv_times: List.duplicate(nil, state.pong_node_count)
            }
        end
      else
        state.current_measurement
      end

    index = String.to_integer(index)

    current_measurement =
      update_in(current_measurement.send_times, &List.update_at(&1, index, fn nil -> time end))

    {:noreply, %State{state | current_measurement: current_measurement}}
  end

  def handle_cast(
        {:stop_measuring, time, index},
        %State{current_measurement: current_measurement} = state
      ) do
    index = String.to_integer(index)

    current_measurement =
      update_in(current_measurement.recv_times, &List.update_at(&1, index, fn nil -> time end))

    if Enum.any?(current_measurement.recv_times, &is_nil/1) do
      {:noreply, %State{state | current_measurement: current_measurement}}
    else
      # Logger.debug("#{inspect(current_measurement)}")
      measurements = [current_measurement | state.measurements]
      {:noreply, %State{state | current_measurement: nil, measurements: measurements}}
    end
  end

  defp header([h | _t] = _measurements) do
    send_times_header =
      Enum.with_index(h.send_times)
      |> Enum.map(fn {_, i} -> "st_#{String.pad_leading("#{i}", 3, "0")}[us]" end)

    recv_times_header =
      Enum.with_index(h.recv_times)
      |> Enum.map(fn {_, i} -> "rt_#{String.pad_leading("#{i}", 3, "0")}[us]" end)

    took_times_header =
      Enum.with_index(h.recv_times)
      |> Enum.map(fn {_, i} -> "tt_#{String.pad_leading("#{i}", 3, "0")}[us]" end)

    send_times_header ++ recv_times_header ++ took_times_header
  end

  defp body(measurements) do
    Enum.reduce(measurements, [], fn m, rows ->
      row = m.send_times ++ m.recv_times ++ took_times(m.send_times, m.recv_times)
      [row | rows]
    end)
  end

  defp save(file_path, rows) do
    rows
    |> NimbleCSV.RFC4180.dump_to_stream()
    |> Enum.join()
    |> then(&File.write(file_path, &1))
  end

  def took_times(send_times, recv_times) do
    send_times_count = Enum.count(send_times)

    recv_times
    |> Enum.with_index()
    |> Enum.map(fn {recv_time, index} ->
      if send_times_count == 1 do
        {Enum.at(send_times, 0), recv_time}
      else
        {Enum.at(send_times, index), recv_time}
      end
    end)
    |> Enum.map(fn {send_time, recv_time} -> recv_time - send_time end)
  end
end
