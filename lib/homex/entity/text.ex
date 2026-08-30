defmodule Homex.Entity.Text do
  use Homex.Entity

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 enabled_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc:
                     "Controls whether this entity is enabled by default. When set to true, the entity is enabled and usable immediately. Disabled entities are hidden by default until you enable them from the device page."
                 ],
                 visible_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc:
                     "Control whether this entity is visible by default. When set to false, the entity is hidden and does not appear on dashboards until you manually make it visible in its settings."
                 ],
                 min: [
                   required: false,
                   type: :integer,
                   default: 0,
                   doc: "The minimum size of a text being set or received."
                 ],
                 max: [
                   required: false,
                   type: :integer,
                   default: 255,
                   doc: "The maximum size of a text being set or received."
                 ],
                 mode: [
                   required: false,
                   type: {:in, [:text, :password]},
                   default: :text,
                   doc: "The mode of the text entity"
                 ],
                 pattern: [
                   required: false,
                   type: :string,
                   doc:
                     "A valid regular expression the text being set or received must match with."
                 ],
                 retain: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "if the last state should be retained"
                 ]
               )
               |> NimbleOptions.new!()

  @moduledoc """
  A text entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/text.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyText do
    use Homex.Entity.Text, id: :my_text, name: "My Text"

    def handle_text(entity, text) do
      IO.puts("Text set to \#{text}")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Gets called when the text has changed.
  """
  @callback handle_text(entity :: Entity.t(), text :: String.t()) :: entity :: Entity.t()

  @optional_callbacks handle_text: 2

  defmacro __using__(opts) do
    quote do
      unquote(Homex.Entity.__entity__(__MODULE__, opts, set_text: 2, set_attributes: 2))

      def handle_text(entity, _text), do: entity
      defoverridable handle_text: 2
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :text,
      fields: %{state: :state, attrs: :state},
      name: opts[:name],
      options: %{
        enabled_by_default: opts[:enabled_by_default],
        visible_by_default: opts[:visible_by_default],
        min: opts[:min],
        max: opts[:max],
        mode: opts[:mode],
        pattern: opts[:pattern]
      },
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity) do
    m.handle_init(entity)
  end

  @impl Homex.Entity
  def handle_command(%{state: text}, %{module: m} = entity),
    do: entity |> set_text(text) |> m.handle_text(text)

  def handle_command(_, entity), do: entity

  @doc """
  Sets the text
  """
  @spec set_text(Entity.t(), text :: String.t()) :: Entity.t()
  def set_text(%Entity{} = entity, text), do: Entity.put_change(entity, :state, text)

  @doc """
  Sets the attributes
  """
  @spec set_attributes(Entity.t(), map()) :: Entity.t()
  def set_attributes(%Entity{} = entity, attrs) when is_map(attrs) do
    Entity.put_change(entity, :attrs, attrs)
  end
end
