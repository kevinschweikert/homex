defmodule Homex.Device do
  @type id() :: atom()

  @type t() :: %__MODULE__{
          id: id(),
          name: String.t(),
          via: id() | nil,
          manufacturer: String.t() | nil,
          model: String.t() | nil,
          serial_number: String.t() | nil,
          sw_version: String.t() | nil,
          hw_version: String.t() | nil
        }

  defstruct [
    :id,
    :name,
    :via,
    :manufacturer,
    :model,
    :serial_number,
    :sw_version,
    :hw_version
  ]

  @schema [
            via: [
              required: false,
              type: :atom,
              doc: "the id of the device this one is connected through"
            ],
            name: [required: false, type: {:or, [:string, :mfa]}],
            manufacturer: [required: false, type: {:or, [:string, :mfa]}],
            model: [required: false, type: {:or, [:string, :mfa]}],
            serial_number: [required: false, type: {:or, [:string, :mfa]}],
            sw_version: [required: false, type: {:or, [:string, :mfa]}],
            hw_version: [required: false, type: {:or, [:string, :mfa]}]
          ]
          |> NimbleOptions.new!()

  @moduledoc "#{NimbleOptions.docs(@schema)}"

  @spec new(id(), keyword()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def new(id, opts \\ []) when is_atom(id) do
    with {:ok, opts} <- NimbleOptions.validate(opts, @schema) do
      opts = Keyword.new(opts, fn {key, value} -> {key, resolve(value)} end)
      opts = Keyword.merge([id: id, name: to_string(id)], opts)
      {:ok, struct!(__MODULE__, opts)}
    end
  end

  defp resolve({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a), do: apply(m, f, a)
  defp resolve(value), do: value
end
