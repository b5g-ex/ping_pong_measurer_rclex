# PingPongMeasurerRclex

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ping_pong_measurer_rclex>.

## Prerequisites

Setup two Raspberry Pi 4 as ping/pong targets by using https://github.com/b5g-ex/setup_ping_pong_pi.

Follow the [README.md](https://github.com/b5g-ex/setup_ping_pong_pi/blob/main/README.md) to setup.

## How to measure

On your Raspberry Pi 4 Ping/Pong targets,

### On pong target

Before doing following, you need to connect `pong` target via SSH,

```bash
cd ping_pong_measurer_rclex/
iex -S mix
```

On IEx,

```elixir
# help arguments
h PingPongMeasurerRclex.start_pong_processes
#
PingPongMeasurerRclex.start_pong_processes(1, :single, :single)
```

Then, invoke command on `ping`'s IEx.

If you wanna change the parameters, you can stop `pong` by,

```elixir
PingPongMeasurerRclex.stop_pong_processes()
```

### On ping target

Before doing following, you need to prepare `pong` first and connect `ping` target via SSH,

```bash
cd ping_pong_measurer_rclex/
iex -S mix
```

On IEx,

```elixir
# help arguments
h PingPongMeasurerRclex.start_ping_side_processes
# start measuring
PingPongMeasurerRclex.start_ping_side_processes(1, :single, :single, 256, 100, false)
```

## For development

On your host machine, you can test pingpong on one Erlang VM.

```bash
cd ping_pong_measurer_rclex/
mix deps.get
iex -S mix
```

On IEx,

```elixir
# help arguments
h PingPongMeasurerRclex.local_test
#
PingPongMeasurerRclex.local_test(1, :single, :single, 256)
```
