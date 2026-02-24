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

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity

      @name opts[:name]
      @platform "device_automation"
      @unique_id Homex.unique_id(@name, [@platform])
      @state_topic "homex/#{@platform}/#{@unique_id}/action"
      @payload opts[:payload]
      @device_type opts[:type]
      @subtype opts[:subtype]

      @impl Homex.Entity
      def name, do: @name

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def platform, do: @platform

      @impl Homex.Entity
      def subscriptions, do: []

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          name: @name,
          unique_id: @unique_id,
          type: @device_type,
          payload: @payload,
          topic: "homex/#{@platform}/#{@unique_id}/action",
          automation_type: "trigger",
          subtype: @subtype
        }
      end

      @impl Homex.Entity
      def setup_entity(entity) do
        entity
        |> Entity.register_handler(:trigger, fn val ->
          Homex.publish(@state_topic, @payload, [])
        end)
      end

      @impl Homex.Entity
      def handle_init(entity), do: super(entity)

      defoverridable handle_init: 1
    end
  end
end
