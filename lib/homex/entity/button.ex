defmodule Homex.Entity.Button do
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 enabled_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "Flag which defines if the entity should be enabled when first added."
                 ],
                 device_class: [
                   required: false,
                   type: {:in, [nil, "identify", "restart", "update"]},
                   default: nil,
                   doc:
                     "The type/class of the button to set the icon in the frontend. The device_class can be nil."
                 ],
                 retain: [
                   required: false,
                   type: :boolean,
                   default: false,
                   doc: "if the last state should be retained"
                 ]
               ]
               |> NimbleOptions.new!()

  @moduledoc """
  A button entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  https://www.home-assistant.io/integrations/button.mqtt/

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyButton do
    use Homex.Entity.Button, name: "my-button"

    def handle_press(entity) do
      IO.puts("my button was pressed")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  get's called when the button is pressed in Home Assistant 
  """
  @callback handle_press(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  sets the buttons attributes
  """
  @callback set_attributes(entity :: Entity.t(), attributes :: Map.t()) :: entity :: Entity.t()

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity

      @behaviour Homex.Entity.Button

      @impl Homex.Entity
      def descriptor do
        %Homex.Descriptor{
          kind: :button,
          fields: %{pressed: :event, attrs: :state},
          name: unquote(opts[:name]),
          options: %{device_class: unquote(opts[:device_class])},
          transport: %{mqtt: [retain: unquote(opts[:retain])]}
        }
      end

      def handle_command(%{pressed: true}, entity) do
        entity |> handle_press()
      end

      def handle_command(_cmd, entity), do: entity

      @impl Homex.Entity.Button
      def handle_press(entity), do: entity

      @impl Homex.Entity.Button
      def set_attributes(%Entity{} = entity, attrs) when is_map(attrs) do
        Entity.put_change(entity, :attrs, attrs)
      end

      @impl Homex.Entity
      def handle_init(entity), do: super(entity)

      defoverridable handle_init: 1, handle_press: 1
    end
  end
end
