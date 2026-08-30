defmodule Homex.Entity.DeviceTrigger do
  use Homex.Entity

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
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
               )
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
    use Homex.Entity.DeviceTrigger, id: :my_device, name: "My Device"
  end
  ```

  Fire the trigger from your code:

  ```elixir
  iex> Homex.Entity.DeviceTrigger.trigger(:my_device)
  :ok
  ```

  ## Running without a module

  A device trigger has no custom callbacks to implement, so unlike the other
  kinds it is meant to be run bare — pass the kind module directly to Homex
  instead of defining your own module:

  ```elixir
  {Homex.Entity.DeviceTrigger, id: :my_device, name: "My Device"}
  ```

  Run bare like this and the OTP handler callbacks (`handle_init`,
  `handle_info`, `handle_call`, `handle_cast`) fall back to no-op defaults. If
  you need to react to those messages, `use Homex.Entity.DeviceTrigger` in your
  own module and override them there.
  """

  alias Homex.Entity

  defmacro __using__(opts), do: Homex.Entity.__entity__(__MODULE__, opts)

  @doc "Fires the trigger"
  def trigger(id), do: Entity.send_command(id, %{trigger: true})

  # DeviceTrigger is meant to run bare, so it opts into being a runnable entity
  # and carries the handler defaults itself instead of getting them from `use`.
  @doc false
  def __homex_entity__, do: true

  def handle_init(entity), do: entity
  def handle_info(_msg, entity), do: entity
  def handle_call(_msg, entity), do: {{:error, :not_handled}, entity}
  def handle_cast(_msg, entity), do: entity

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :device_trigger,
      fields: %{trigger: :event},
      name: opts[:name],
      options: %{
        type: opts[:type],
        subtype: opts[:subtype],
        payload: opts[:payload],
        enabled_by_default: opts[:enabled_by_default]
      }
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity), do: m.handle_init(entity)

  @impl Homex.Entity
  def handle_command(%{trigger: true}, entity), do: Entity.put_change(entity, :trigger, true)
  def handle_command(_cmd, entity), do: entity
end
