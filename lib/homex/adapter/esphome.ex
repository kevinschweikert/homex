defmodule Homex.Adapter.ESPHome do
  @options_schema [
                    port: [
                      required: false,
                      type: :integer,
                      default: 6053,
                      doc: "TCP port the native API listens on"
                    ],
                    mdns: [
                      required: false,
                      type: :atom,
                      doc:
                        "an `Espex.Mdns` adapter, such as `Espex.Mdns.MdnsLite`. Without one the instance is not advertised and has to be added to Home Assistant by address"
                    ],
                    espex_opts: [
                      required: false,
                      default: [],
                      type: :keyword_list,
                      doc:
                        "passed to `Espex` untouched and merged last, so it can override anything derived from the options above. A nested list such as `:device_config` is merged one level deep, so setting a key in it does not drop the ones homex derived. Unvalidated — the accepted keys are espex's, not homex's"
                    ]
                  ]
                  |> NimbleOptions.new!()

  @moduledoc """
  ESPHome native API transport.

  Home Assistant talks to homex as if it were an ESPHome device: it connects over
  the native API, reads the entities and subscribes to their state. The `:node_id`
  becomes the device name it discovers.

  Requires `:espex`, which homex does not pull in on its own, plus `:mdns_lite` for
  the `:mdns` option below — `Espex.Mdns.MdnsLite` late-binds it, so espex does not
  pull it in either:

      {:espex, "~> 0.9"},
      {:mdns_lite, "~> 0.8"}

  `:mdns_lite` cannot be installed from a Livebook: it builds its DNS records with
  `Record.extract/2` from `kernel/src/inet_dns.hrl`, and Livebook's bundled Erlang
  ships no OTP source headers. Leave `:mdns` out there and add the device to Home
  Assistant by address, as `example.livemd` does.

  Start it from the `:adapters` option of `Homex`:

      {Homex,
       node_id: Homex.hostname(),
       adapters: [{Homex.Adapter.ESPHome, mdns: Espex.Mdns.MdnsLite}],
       entities: [MySwitch]}

  Anything espex takes that homex does not model goes through `:espex_opts`, for
  example the pre-shared key of the encrypted transport:

      {Homex.Adapter.ESPHome, espex_opts: [device_config: [psk: "base64-encoded-psk"]]}

  Only one instance can run per VM.

  Home Assistant caches the entity list per connection, so an entity added or
  removed at runtime only reaches it on reconnect.

  ## Options

  #{NimbleOptions.docs(@options_schema)}
  """

  use Supervisor

  alias Homex.Adapter.ESPHome.EntityProvider

  # espex calls EntityProvider as a bare module, so this adapter is a singleton
  @server __MODULE__.Server
  @supervisor __MODULE__.Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, NimbleOptions.validate!(opts, @options_schema),
      name: __MODULE__
    )
  end

  @impl Supervisor
  def init(opts) do
    children = [
      {EntityProvider, server: @server},
      {Espex, espex_opts(opts)}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp espex_opts(opts) do
    [
      name: @supervisor,
      server_name: @server,
      entity_provider: EntityProvider,
      port: opts[:port],
      mdns: opts[:mdns],
      device_config: [name: Homex.node_id()]
    ]
    |> Keyword.reject(fn {_key, val} -> is_nil(val) end)
    |> Keyword.merge(opts[:espex_opts], &merge_nested/3)
  end

  defp merge_nested(_key, derived, override) do
    if Keyword.keyword?(derived) and Keyword.keyword?(override),
      do: Keyword.merge(derived, override),
      else: override
  end
end
