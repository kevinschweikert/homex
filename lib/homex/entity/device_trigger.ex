defmodule Homex.Entity.DeviceTrigger do
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 enabled_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "Flag which defines if the entity should be enabled when first added."
                 ],
                 payload: [
                   required: false,
                   type: :string,
                   default: "action",
                   doc: "Optional payload to match the payload being sent over the topic."
                 ],
                 type: [
                   required: false,
                   type: :string,
                   default: "button_short_press",
                   doc: "The type of the trigger, e.g. button_short_press.."
                 ],
                 subtype: [
                   required: false,
                   type: :string,
                   default: "button_1",
                   doc: "The subtype of the trigger, e.g. button_1."
                 ]
               ]
               |> NimbleOptions.new!()

  @moduledoc """
  A Device Trigger entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  https://www.home-assistant.io/integrations/device_trigger.mqtt/

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyDevice do
    use Homex.Entity.DeviceTrigger, name: "my-device"
  end
  ```

  Trigger using the trigger/0 function

  ```elixir
  iex> MyDevice.trigger()
  :ok
  ```
  """

  alias Homex.Entity

  @doc "fires a trigger to the entity"
  def trigger(name), do: Homex.notify(name, :device_trigger_fire)

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity

      @impl Homex.Entity
      def descriptor do
        %Homex.Descriptor{
          kind: :device_trigger,
          fields: %{trigger: :event},
          name: unquote(opts[:name]),
          options: %{
            type: unquote(opts[:type]),
            subtype: unquote(opts[:subtype]),
            payload: unquote(opts[:payload]),
            enabled_by_default: unquote(opts[:enabled_by_default])
          }
        }
      end

      def handle_info(:device_trigger_fire, entity), do: Entity.put_change(entity, :trigger, true)
      def handle_info(_, entity), do: entity

      @impl Homex.Entity
      def handle_init(entity), do: super(entity)

      defoverridable handle_init: 1
    end
  end
end
