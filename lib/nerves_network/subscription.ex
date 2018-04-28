defmodule Nerves.Network.Subscription do
  @moduledoc """
  Wraps Elixir.Registry and SystemRegistry so end uses don't need to worry
  about subscribing to both.
  """

  use GenServer
  alias Nerves.Network.Utils
  @registry Nerves.Network

  @doc "Subscribe to network events."
  def subscribe(ifname) when is_binary(ifname) do
    Registry.register(@registry, ifname, [])
  end

  @doc false
  def start_link(ifname, opts) when is_binary(ifname) do
    GenServer.start_link(__MODULE__, [ifname], opts)
  end

  @doc false
  def stop(ifname) when is_binary(ifname) do
    GenServer.stop(sub_name(ifname), :shutdown)
  end

  @doc false
  def init([ifname]) do
    {:ok, _} = Registry.register(Nerves.NetworkInterface, ifname, [])
    {:ok, _} = Registry.register(Nerves.Udhcpc, ifname, [])
    {:ok, _} = Registry.register(Nerves.WpaSupplicant, ifname, [])
    {:ok, %{ifname: ifname}}
  end

  @doc false
  def handle_info({:system_registry, :global, registry}, %{ifname: ifname} = s) do
    ifstate = get_in(registry, [:state, :network_interface, ifname])

    if ifstate do
      IO.puts("A+")
      Utils.notify(@registry, ifname, SystemRegistry, {:state, ifstate})
      {:noreply, Map.merge(s, ifstate)}
    else
      {:noreply, s}
    end
  end

  def handle_info({registry, notif, data}, %{ifname: ifname} = s)
      when registry in [Nerves.NetworkInterface, Nerves.WpaSupplicant, Nerves.Udhcpc] do
    Utils.notify(@registry, ifname, registry, {notif, data})
    {:noreply, Map.merge(s, data)}
  end

  def handle_info(_, state), do: {:noreply, state}

  @doc "Gets the GenServer name of an interface for this module."
  def sub_name(ifname) when is_binary(ifname) do
    Module.concat(__MODULE__, ifname)
  end
end
