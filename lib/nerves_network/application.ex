defmodule Nerves.Network.Application do
  @moduledoc false
  alias Nerves.Network.{
    Resolvconf,
    IFSupervisor,
    Config
  }

  use Application

  def start(_type, _args) do
    children = [
      {Registry, [keys: :duplicate, name: Nerves.Udhcpc]},
      {Registry, [keys: :duplicate, name: Nerves.Network]},
      %{
        id: Resolvconf,
        start: {Resolvconf, :start_link, ["/tmp/resolv.conf", [name: Resolvconf]]}
      },
      %{id: IFSupervisor, start: {IFSupervisor, :start_link, [[name: IFSupervisor]]}},
      %{id: Config, start: {Config, :start_link, []}}
    ]

    opts = [strategy: :rest_for_one, name: Nerves.Network.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
