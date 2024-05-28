defmodule PingPongMeasurerRclex.MeasurerTest do
  use ExUnit.Case

  alias PingPongMeasurerRclex.Measurer

  test "took_times/2" do
    # single, single
    assert Measurer.took_times([1], [3, 4]) == [2, 3]
    # single, multiple
    assert Measurer.took_times([1], [3, 4]) == [2, 3]
    # multiple, single
    assert Measurer.took_times([1, 2], [3, 4]) == [2, 2]
    # multiple, multiple
    assert Measurer.took_times([1, 2], [3, 4]) == [2, 2]
  end
end
