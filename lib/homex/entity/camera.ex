defmodule Homex.Entity.Camera do
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 update_interval: [
                   required: false,
                   type: {:or, [:atom, :integer]},
                   default: 10_000,
                   doc:
                     "the interval in milliseconds in which `handle_timer/1` get's called. Can also be `:never` to disable the timer callback"
                 ],
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
               ]
               |> NimbleOptions.new!()

  @moduledoc """
  A camera entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/camera.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Overridable Functions

  The following functions can be overridden in your entity:

  * `handle_init/1` - From `Homex.Entity`
  * `handle_timer/1` - From `Homex.Entity`

  ### Default Implementations

  All overridable functions have safe default implementations that return the entity unchanged.
  You only need to override the functions you want to customize.

  ## Example

  ```elixir
  defmodule MyCamera do
    use Homex.Entity.Camera, name: "my-camera"

    def handle_timer(entity) do
      img = Image.open!("some/path/to/image.jpg") |> Image.write!(:memory, suffix: ".jpg")
      entity |> set_image(img) |> set_attributes(%{foo: "bar"})
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  sets the image
  """
  @callback set_image(entity :: Entity.t(), image :: binary()) :: entity :: Entity.t()

  @doc """
  sets the attributes
  """
  @callback set_attributes(entity :: Entity.t(), attributes :: Map.t()) :: entity :: Entity.t()

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity, update_interval: opts[:update_interval]
      @behaviour Homex.Entity.Camera

      @name opts[:name]
      @platform "camera"
      @unique_id Homex.unique_id(@name, [@platform])
      @topic "homex/#{@platform}/#{@unique_id}"
      @json_attributes_topic "homex/#{@platform}/#{@unique_id}/attributes"
      @retain opts[:retain]
      @encoding opts[:encoding]
      @image_encoding opts[:image_encoding]
      @enabled_by_default opts[:enabled_by_default]

      @impl Homex.Entity
      def name, do: @name

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions, do: []

      @impl Homex.Entity
      def platform(), do: @platform

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          topic: @topic,
          json_attributes_topic: @json_attributes_topic,
          name: @name,
          unique_id: @unique_id,
          encoding: @encoding,
          image_encoding: @image_encoding,
          enabled_by_default: @enabled_by_default
        }
        |> Map.reject(fn {_key, val} -> is_nil(val) end)
      end

      @impl Homex.Entity
      def setup_entity(entity) do
        entity
        |> Entity.register_handler(:image, fn image ->
          Homex.publish(@topic, image, retain: @retain)
        end)
        |> Entity.register_handler(:attrs, fn attrs ->
          Homex.publish(@json_attributes_topic, attrs, retain: @retain)
        end)
      end

      @impl Homex.Entity
      def handle_init(entity), do: super(entity)

      @impl Homex.Entity
      def handle_timer(entity), do: super(entity)

      @impl Homex.Entity.Camera
      def set_image(%Entity{} = entity, image) when is_binary(image) do
        Entity.put_change(entity, :image, image)
      end

      @impl Homex.Entity.Camera
      def set_attributes(%Entity{} = entity, attrs) when is_map(attrs) do
        Entity.put_change(entity, :attrs, Jason.encode!(attrs))
      end

      defoverridable handle_init: 1, handle_timer: 1
    end
  end
end
