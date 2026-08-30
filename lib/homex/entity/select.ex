defmodule Homex.Entity.Select do
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
                 options: [
                   required: true,
                   type: {:list, :string},
                   doc: "List of options that can be selected."
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
  A select entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/select.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MySelect do
    use Homex.Entity.Select, id: :my_select, name: "My Select", options: ["one", "two", "three"]

    def handle_option(entity, option) do
      IO.puts("Option set to \#{option}")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Gets called when the selected option has changed.
  """
  @callback handle_option(entity :: Entity.t(), option :: String.t()) :: entity :: Entity.t()

  @optional_callbacks handle_option: 2

  defmacro __using__(opts) do
    quote do
      unquote(Homex.Entity.__entity__(__MODULE__, opts, set_option: 2))

      def handle_option(entity, _option), do: entity
      defoverridable handle_option: 2
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :select,
      fields: %{state: :state},
      name: opts[:name],
      options: %{
        enabled_by_default: opts[:enabled_by_default],
        visible_by_default: opts[:visible_by_default],
        options: opts[:options]
      },
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity) do
    m.handle_init(entity)
  end

  @impl Homex.Entity
  def handle_command(%{state: option}, %{module: m} = entity),
    do: entity |> set_option(option) |> m.handle_option(option)

  def handle_command(_, entity), do: entity

  @doc """
  Sets the selected option
  """
  @spec set_option(Entity.t(), option :: String.t()) :: Entity.t()
  def set_option(%Entity{} = entity, option), do: Entity.put_change(entity, :state, option)
end
