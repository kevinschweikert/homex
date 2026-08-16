defmodule Homex.Entity.Switch do
  use Homex.Entity

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 retain: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "if the last state should be retained"
                 ]
               )
               |> NimbleOptions.new!()

  @moduledoc """
  A switch entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/switch.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MySwitch do
    use Homex.Entity.Switch, name: "my-switch"

    def handle_on(entity) do
      IO.puts("Switch turned on")
      entity
    end

    def handle_off(entity) do
      IO.puts("Switch turned off")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Gets called when the switch receives an on command
  """
  @callback handle_on(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the switch receives an off command
  """
  @callback handle_off(entity :: Entity.t()) :: entity :: Entity.t()

  @optional_callbacks handle_on: 1, handle_off: 1

  defmacro __using__(opts) do
    quote do
      unquote(Homex.Entity.__entity__(__MODULE__, opts, set_on: 1, set_off: 1))

      def handle_on(entity), do: entity
      def handle_off(entity), do: entity
      defoverridable handle_on: 1, handle_off: 1
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :switch,
      fields: %{state: :state},
      name: opts[:name],
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity), do: m.handle_init(set_off(entity))

  @impl Homex.Entity
  def handle_command(%{state: true}, %{module: m} = entity), do: m.handle_on(set_on(entity))
  def handle_command(%{state: false}, %{module: m} = entity), do: m.handle_off(set_off(entity))
  def handle_command(_cmd, entity), do: entity

  @doc """
  Sets the switch state to on
  """
  @spec set_on(Entity.t()) :: Entity.t()
  def set_on(%Entity{} = entity), do: Entity.put_change(entity, :state, true)

  @doc """
  Sets the switch state to off
  """
  @spec set_off(Entity.t()) :: Entity.t()
  def set_off(%Entity{} = entity), do: Entity.put_change(entity, :state, false)
end
