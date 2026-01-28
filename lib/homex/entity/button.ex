defmodule Homex.Entity.Button do
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 enabled_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "Flag which defines if the entity should be enabled when first added."
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
  end
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
      @action "press"

      @impl Homex.Entity
      def name, do: @name

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def platform(), do: @platform

      @impl Homex.Entity
      def subscriptions, do: []

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          name: @name,
          unique_id: @unique_id,
          type: "action",
          payload: @action,
          topic: "homex/#{@platform}/#{@unique_id}/action",
          automation_type: :trigger,
          subtype: @action
        }
      end

      @impl Homex.Entity
      def setup_entity(entity) do
        entity
        |> Entity.register_handler(:press, fn val ->
          Homex.publish(@state_topic, @action, [])
        end)
      end

      def press(%Homex.Entity{} = entity) do
        entity |> Entity.put_change(:press, @action) |> Entity.execute_change()
      end

      @impl Homex.Entity
      def handle_init(entity), do: super(entity)

      defoverridable handle_init: 1
    end
  end
end
