defmodule Homex.Adapter.ESPHome.Mdns.SystemResponder do
  @moduledoc """
  An `Espex.Mdns` adapter that advertises through the mDNS responder of the
  operating system.

  Use it on a desktop or a server, where a responder already runs. It also works
  in a Livebook, unlike `Espex.Mdns.MdnsLite`. The `:mdns` option of
  `Homex.Adapter.ESPHome` takes `:system` for it:

      {Homex,
       node_id: Homex.hostname(),
       adapters: [{Homex.Adapter.ESPHome, mdns: :system}],
       entities: [MySwitch]}

  This adapter needs `:muontrap`. Homex does not include the dependency.

      {:muontrap, "~> 2.0"}

  The adapter runs the first of these programs that it finds:

    * `dns-sd` - part of Bonjour. macOS has it. On Linux it comes with the
      `avahi-compat` package.
    * `avahi-publish` - part of `avahi-utils` on Linux.

  The program runs as long as homex advertises. `:muontrap` ends it when the
  adapter withdraws, and also when the VM stops.

  ## Limitations

    * Nerves has no responder of this kind. Use `Espex.Mdns.MdnsLite` there.
    * The responder gives the host name of the machine as the address of the
      service. Home Assistant must be able to resolve that name.
  """

  @behaviour Espex.Mdns

  @daemon __MODULE__.Daemon

  @programs [{"dns-sd", :dns_sd}, {"avahi-publish", :avahi}]

  @impl Espex.Mdns
  def advertise(service) do
    with {:ok, path, flavor} <- find_program(),
         {:ok, _pid} <-
           MuonTrap.Daemon.start_link(path, args(flavor, service),
             name: @daemon,
             log_output: :debug,
             stderr_to_stdout: true
           ) do
      :ok
    end
  end

  @impl Espex.Mdns
  def withdraw(_service_id) do
    if pid = Process.whereis(@daemon), do: GenServer.stop(pid)

    :ok
  end

  defp find_program() do
    Enum.find_value(@programs, {:error, :no_mdns_program}, fn {name, flavor} ->
      case System.find_executable(name) do
        nil -> nil
        path -> {:ok, path, flavor}
      end
    end)
  end

  defp args(:dns_sd, service) do
    ["-R", instance_name(service), type(service), "local", to_string(service.port)] ++
      service.txt_payload
  end

  defp args(:avahi, service) do
    ["-s", instance_name(service), type(service), to_string(service.port)] ++ service.txt_payload
  end

  defp type(service), do: "_#{service.protocol}._#{service.transport}"

  defp instance_name(%{instance_name: name}) when is_binary(name), do: name
  defp instance_name(_service), do: Homex.node_id()
end
