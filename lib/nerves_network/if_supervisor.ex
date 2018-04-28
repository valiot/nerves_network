defmodule Nerves.Network.IFSupervisor do
  @moduledoc false
  use Supervisor
  alias Nerves.Network.Types
  import Nerves.Network.Utils, only: [log_atomized_iface_error: 1]

  @spec setup(Types.ifname(), Nerves.Network.setup_setting()) :: {:ok, pid} | {:error, term}
  def setup(ifname, settings) when is_binary(ifname) do
    pidname = pname(ifname)

    if !Process.whereis(pidname) do
      manager_module = manager(if_type(ifname), settings)
      sub_name = Nerves.Network.Subscription.sub_name(ifname)
      manager_worker = worker(manager_module, [ifname, settings, [name: pidname]], id: pidname)
      sub_worker = worker(Nerves.Network.Subscription, [ifname, [name: sub_name]], id: sub_name)
      {:ok, _} = Supervisor.start_child(__MODULE__, manager_worker)
      {:ok, _} = Supervisor.start_child(__MODULE__, sub_worker)
    else
      {:error, :already_added}
    end
  end

  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, [], options)
  end

  def init([]) do
    {:ok, {{:one_for_one, 10, 3600}, []}}
  end

  @spec teardown(Types.ifname()) :: :ok | {:error, :not_started}
  def teardown(ifname) when is_binary(ifname) do
    pidname = pname(ifname)
    sub_name = Nerves.Network.Subscription.sub_name(ifname)

    if Process.whereis(pidname) do
      Supervisor.terminate_child(__MODULE__, pidname)
      Supervisor.terminate_child(__MODULE__, sub_name)
      Supervisor.delete_child(__MODULE__, pidname)
      Supervisor.delete_child(__MODULE__, sub_name)
    else
      {:error, :not_started}
    end
  end

  @spec scan(Types.ifname()) :: [String.t()] | {:error, any}
  def scan(ifname) when is_binary(ifname) do
    with pid when is_pid(pid) <- Process.whereis(pname(ifname)),
         :wireless <- if_type(ifname) do
      GenServer.call(pid, :scan, 30_000)
    else
      # If there is no pid.
      nil ->
        {:error, :not_started}

      # if the interface was wired.
      :wired ->
        {:error, :not_wireless}
    end
  end

  @spec pname(Types.ifname()) :: atom
  defp pname(ifname) do
    String.to_atom("Nerves.Network.Interface." <> ifname)
  end

  # Return the appropriate interface manager based on the interface's type
  # and settings
  @spec manager(:wired | :wireless, Nerves.Network.setup_settings()) ::
          Nerves.Network.StaticManager
          | Nerves.Network.LinkLocalManager
          | Nerves.Network.DHCPManager
          | Nerves.Network.WiFiManager
  defp manager(:wired, settings) do
    case Keyword.get(settings, :ipv4_address_method) do
      :static ->
        Nerves.Network.StaticManager

      :linklocal ->
        Nerves.Network.LinkLocalManager

      :dhcp ->
        Nerves.Network.DHCPManager

      # Default to DHCP if unset; crash if anything else.
      nil ->
        Nerves.Network.DHCPManager
    end
  end

  defp manager(:wireless, _settings) do
    Nerves.Network.WiFiManager
  end

  @spec if_type(Types.ifname()) :: :wired | :wireless
  # Categorize networks into wired and wireless based on their if names
  defp if_type(<<"eth", _rest::binary>>), do: :wired
  defp if_type(<<"usb", _rest::binary>>), do: :wired
  # Localhost
  defp if_type(<<"lo", _rest::binary>>), do: :wired
  defp if_type(<<"wlan", _rest::binary>>), do: :wireless
  # Ralink
  defp if_type(<<"ra", _rest::binary>>), do: :wireless

  # systemd predictable names
  defp if_type(<<"en", _rest::binary>>), do: :wired
  # SLIP
  defp if_type(<<"sl", _rest::binary>>), do: :wired
  defp if_type(<<"wl", _rest::binary>>), do: :wireless
  # wwan (not really supported)
  defp if_type(<<"ww", _rest::binary>>), do: :wired

  defp if_type(_ifname), do: :wired
end
