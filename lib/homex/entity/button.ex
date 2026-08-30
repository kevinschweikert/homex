defmodule Homex.Entity.Button do
  use Homex.Entity

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
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
               )
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
    use Homex.Entity.Button, id: :my_button, name: "My Button"

    def handle_press(entity) do
      IO.puts("my button was pressed")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Gets called when the button is pressed in Home Assistant
  """
  @callback handle_press(entity :: Entity.t()) :: entity :: Entity.t()

  @optional_callbacks handle_press: 1

  defmacro __using__(opts) do
    quote do
      unquote(Homex.Entity.__entity__(__MODULE__, opts, set_attributes: 2))

      def handle_press(entity), do: entity
      defoverridable handle_press: 1
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :button,
      fields: %{pressed: :event, attrs: :state},
      name: opts[:name],
      options: %{
        device_class: opts[:device_class],
        enabled_by_default: opts[:enabled_by_default]
      },
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity), do: m.handle_init(entity)

  @impl Homex.Entity
  def handle_command(%{pressed: true}, %{module: m} = entity),
    do: entity |> m.handle_press() |> Entity.put_change(:pressed, true)

  def handle_command(_cmd, entity), do: entity

  @doc """
  Sets the buttons attributes
  """
  @spec set_attributes(Entity.t(), map()) :: Entity.t()
  def set_attributes(%Entity{} = entity, attrs) when is_map(attrs) do
    Entity.put_change(entity, :attrs, attrs)
  end
end
