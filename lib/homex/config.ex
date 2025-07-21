defmodule Homex.Config do
  @moduledoc false

  @type t() :: %__MODULE__{
          device: map(),
          origin: map(),
          discovery_prefix: String.t(),
          entities: [module()],
          broker: [
            name: atom(),
            host: charlist(),
            port: :inet.port_number(),
            username: charlist(),
            password: charlist()
          ]
        }

  defstruct [:device, :origin, :discovery_prefix, :entities, :broker]

  def new(opts) do
    config = opts |> NimbleOptions.validate!(Homex.config_schema())

    device = config |> make_device_config()
    origin = config |> make_origin_config()
    broker = config |> make_broker_config()

    %__MODULE__{
      device: device,
      origin: origin,
      broker: broker,
      discovery_prefix: config[:discovery_prefix],
      entities: config[:entities]
    }
  end

  defp make_device_config(opts) do
    opts
    |> Keyword.get(:device, [])
    |> Keyword.merge(name: {Homex, :hostname, []}, identifiers: [{Homex, :hostname, []}])
    |> map_opts()
    |> Enum.into(%{})
  end

  defp make_origin_config(opts) do
    opts
    |> Keyword.get(:origin, [])
    |> map_opts()
    |> Enum.into(%{})
  end

  defp map_opts(opts) do
    Enum.map(opts, fn
      {key, list} when is_list(list) -> {key, Enum.map(list, &apply_mfa/1)}
      {key, {_, _, _} = mfa} -> {key, apply_mfa(mfa)}
      {key, value} -> {key, value}
    end)
  end

  defp apply_mfa({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, a)
  end

  defp make_broker_config(opts) do
    config =
      opts
      |> Keyword.get(:broker, [])

    [
      name: Homex.EMQTT,
      host: String.to_charlist(config[:host]),
      port: config[:broker][:port],
      username: optional(config[:username], &String.to_charlist/1),
      password: optional(config[:password], &String.to_charlist/1)
    ]
    |> Keyword.reject(fn {_key, val} -> is_nil(val) end)
  end

  defp optional(val, _) when is_nil(val), do: nil
  defp optional(val, transformer), do: transformer.(val)
end
