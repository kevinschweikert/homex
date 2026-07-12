defmodule Homex.Entity.Switch do
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 update_interval: [
                   required: false,
                   type: {:or, [:atom, :integer]},
                   default: :never,
                   doc:
                     "the interval in milliseconds in which `handle_timer/1` get's called. Can also be `:never` to disable the timer callback"
                 ],
                 retain: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "if the last state should be retained"
                 ]
               ]
               |> NimbleOptions.new!()

  @moduledoc """
  A switch entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/switch.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Overridable Functions

  The following functions can be overridden in your entity:

  * `handle_init/1` - From `Homex.Entity`
  * `handle_timer/1` - From `Homex.Entity`
  * `handle_on/1` - From `Homex.Entity.Switch`
  * `handle_off/1` - From `Homex.Entity.Switch`

  ### Default Implementations

  All overridable functions have safe default implementations that return the entity unchanged.
  You only need to override the functions you want to customize.

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
  Sets the switch state to on
  """
  @callback set_on(entity :: Entity.t()) :: entity :: Entity.t()
  @doc """
  Sets the switch state to off
  """
  @callback set_off(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the command topic receieves an `on_payload`
  """
  @callback handle_on(entity :: Entity.t()) :: entity :: Entity.t() | {:error, reason :: term()}

  @doc """
  Gets called when the command topic receieves an `off_payload`
  """
  @callback handle_off(entity :: Entity.t()) :: entity :: Entity.t() | {:error, reason :: term()}

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity, update_interval: opts[:update_interval]

      @behaviour Homex.Entity.Switch

      @impl Homex.Entity
      def descriptor do
        %Homex.Descriptor{
          kind: :switch,
          fields: %{state: :state},
          name: unquote(opts[:name]),
          transport: %{mqtt: [retain: unquote(opts[:retain])]}
        }
      end

      @impl Homex.Entity
      def handle_command(%{state: true}, entity) do
        entity |> set_on() |> handle_on()
      end

      def handle_command(%{state: false}, entity) do
        entity |> set_off() |> handle_off()
      end

      def handle_command(_cmd, entity), do: entity

      @impl Homex.Entity.Switch
      def set_on(%Entity{} = entity) do
        Entity.put_change(entity, :state, true)
      end

      @impl Homex.Entity.Switch
      def set_off(%Entity{} = entity) do
        Entity.put_change(entity, :state, false)
      end

      @impl Homex.Entity.Switch
      def handle_on(entity), do: entity

      @impl Homex.Entity.Switch
      def handle_off(entity), do: entity

      @impl Homex.Entity
      def handle_init(entity), do: entity |> set_off() |> super()

      @impl Homex.Entity
      def handle_timer(entity), do: super(entity)

      defoverridable handle_init: 1, handle_on: 1, handle_off: 1, handle_timer: 1
    end
  end
end
