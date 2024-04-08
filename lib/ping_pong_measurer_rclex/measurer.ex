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
    pong_node_count = Keyword.fetch!(args, :pong_node_count)
    pub = Keyword.fetch!(args, :pub)
    sub = Keyword.fetch!(args, :sub)

    {:ok, %State{pong_node_count: pong_node_count, pub: pub, sub: sub}}
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
      update_in(current_measurement.send_times, &List.replace_at(&1, index, time))

    {:noreply, %State{state | current_measurement: current_measurement}}
  end

  def handle_cast(
        {:stop_measuring, time, index},
        %State{current_measurement: current_measurement} = state
      ) do
    index = String.to_integer(index)

    current_measurement =
      update_in(current_measurement.recv_times, &List.replace_at(&1, index, time))

    if Enum.any?(current_measurement.recv_times, &is_nil/1) do
      {:noreply, %State{state | current_measurement: current_measurement}}
    else
      Logger.debug("#{inspect(current_measurement)}")
      measurements = [current_measurement | state.measurements]
      {:noreply, %State{state | current_measurement: nil, measurements: measurements}}
    end
  end
end
