defmodule Homex.Entity.Camera do
  use Homex.Entity

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 retain: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "if the last state should be retained"
                 ],
                 enabled_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "Flag which defines if the entity should be enabled when first added."
                 ],
                 encoding: [
                   required: false,
                   type: :string,
                   default: "utf-8",
                   doc:
                     "The encoding of the payloads received. Set to empty string to disable decoding of incoming payload. Use image_encoding to enable Base64 decoding on topic."
                 ],
                 image_encoding: [
                   required: false,
                   default: nil,
                   type: {:or, [nil, :string]},
                   doc:
                     "The encoding of the image payloads received. Set to \"b64\" to enable base64 decoding of image payload. If not set, the image payload must be raw binary data."
                 ]
               )
               |> NimbleOptions.new!()

  @moduledoc """
  A camera entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/camera.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyCamera do
    use Homex.Entity.Camera, name: "my-camera"

    def handle_init(entity) do
      :timer.send_interval(10_000, :snap)
      entity
    end

    def handle_info(:snap, entity) do
      img = Image.open!("some/path/to/image.jpg") |> Image.write!(:memory, suffix: ".jpg")
      entity |> set_image(img) |> set_attributes(%{foo: "bar"})
    end
  end
  ```
  """

  alias Homex.Entity

  defmacro __using__(opts) do
    Homex.Entity.__entity__(__MODULE__, opts, set_image: 2, set_attributes: 2)
  end

  @impl Homex.Entity
  def new(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, @opts_schema) do
      {:ok,
       %Entity{
         name: opts[:name],
         module: __MODULE__,
         descriptor: %Homex.Descriptor{
           kind: :camera,
           fields: %{image: :state, attrs: :state},
           name: opts[:name],
           options: %{
             encoding: opts[:encoding],
             image_encoding: opts[:image_encoding],
             enabled_by_default: opts[:enabled_by_default]
           },
           transport: %{mqtt: [retain: opts[:retain]]}
         }
       }}
    end
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity), do: m.handle_init(entity)

  @impl Homex.Entity
  def handle_command(_cmd, entity), do: entity

  @doc """
  Sets the image
  """
  @spec set_image(Entity.t(), binary()) :: Entity.t()
  def set_image(%Entity{} = entity, image) when is_binary(image) do
    Entity.put_change(entity, :image, image)
  end

  @doc """
  Sets the attributes
  """
  @spec set_attributes(Entity.t(), map()) :: Entity.t()
  def set_attributes(%Entity{} = entity, attrs) when is_map(attrs) do
    Entity.put_change(entity, :attrs, attrs)
  end
end
