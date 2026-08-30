defmodule Homex.Adapter.ESPHome do
  @options_schema [
                    port: [
                      required: false,
                      type: :integer,
                      default: 6053,
                      doc: "The TCP port that the native API uses."
                    ],
                    mdns: [
                      required: false,
                      type: :atom,
                      doc:
                        "How homex advertises the instance. Use `:system` on a desktop, a server or in a Livebook, and `:mdns_lite` on Nerves. Any other atom is an `Espex.Mdns` adapter of your own. If you do not set this option, homex does not advertise the instance. You must then add the device to Home Assistant by its address."
                    ],
                    espex_opts: [
                      required: false,
                      default: [],
                      type: :keyword_list,
                      doc:
                        "Options for `Espex`. Homex merges them last. They replace the values from the options above. Homex merges a nested list, for example `:device_config`, one level deep. Because of this, a key that you set does not remove the keys that homex made. Homex does not validate these options, because espex accepts them."
                    ]
                  ]
                  |> NimbleOptions.new!()

  @moduledoc """
  ESPHome native API transport.

  Home Assistant discovers homex as an ESPHome device. It then connects to homex
  with the native API.

  This adapter needs `:espex`. Homex does not include the dependency.

      {:espex, "~> 0.9"}

  Start the adapter from the `:adapters` option of `Homex`:

      {Homex,
       id: Homex.hostname(),
       adapters: [{Homex.Adapter.ESPHome, mdns: :system}],
       entities: [MySwitch]}

  ## Advertising

  Home Assistant finds the instance over mDNS. The `:mdns` option picks who
  answers, and each choice needs a dependency of its own:

    * `:system` - the responder of the operating system, through
      `Homex.Adapter.ESPHome.Mdns.SystemResponder`. Use it on a desktop, a
      server or in a Livebook. Needs `:muontrap`.
    * `:mdns_lite` - the responder of `Espex.Mdns.MdnsLite`, which answers on
      its own. Use it on Nerves, where nothing else holds port 5353. Needs
      `:mdns_lite`.

  Homex does not include either dependency.

      {:muontrap, "~> 2.0"},
      {:mdns_lite, "~> 0.8"}

  Use `:espex_opts` for espex options that homex does not have:

      {Homex.Adapter.ESPHome, espex_opts: [device_config: [psk: "base64-encoded-psk"]]}

  ## Device limitations

    * `:id` gives the device name. The `:default` `Homex.Device` gives the
      friendly name, the manufacturer and the model.
    * All other devices become flat sub-devices. The native API does not have a
      `:via` chain.
    * The native API has no field for `:serial_number`, `:sw_version` or
      `:hw_version`.
    * espex reads the entity list and the device config when a client connects.
      If you change one of them, the adapter restarts the espex tree. The restart
      disconnects all clients.

  ## Instance limitations

  You can run only one instance for each VM. espex calls the entity provider by
  its module name. Because of this, the name is the same for all instances.

  ## Options

  #{NimbleOptions.docs(@options_schema)}
  """

  use Supervisor

  alias Homex.Adapter.ESPHome.{EspexTree, Mdns, Reloader}

  def start_link(opts \\ []) do
    opts =
      opts
      |> NimbleOptions.validate!(@options_schema)
      |> Keyword.replace_lazy(:mdns, &mdns_adapter/1)

    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(opts) do
    children = [
      {Reloader, supervisor: self()},
      {EspexTree, opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp mdns_adapter(:system), do: Mdns.SystemResponder
  defp mdns_adapter(:mdns_lite), do: Espex.Mdns.MdnsLite
  defp mdns_adapter(module), do: module
end
