# the dashboard is only compiled when the host project brought Kino along
if Code.ensure_loaded?(Kino.JS) do
  defmodule Homex.Livebook do
    @moduledoc """
    Renders a dashboard from the Homex instance you can
    interact with and see the changes live in realtime.
    """

    use Kino.JS, assets_path: "lib/homex/livebook/assets"
    use Kino.JS.Live

    alias Homex.Livebook.{Button, Camera, DeviceTrigger, Kind, Light, Sensor, Switch}

    @kinds %{
      switch: Switch,
      sensor: Sensor,
      light: Light,
      button: Button,
      camera: Camera,
      device_trigger: DeviceTrigger
    }

    @doc "Starts the dashboard"
    def new, do: Kino.JS.Live.new(__MODULE__, nil)

    @impl Kino.JS.Live
    def init(_arg, ctx) do
      Homex.subscribe()
      {:ok, load(ctx)}
    end

    @impl Kino.JS.Live
    def handle_connect(ctx) do
      send(self(), {:images, ctx.origin})
      {:ok, layout(ctx), ctx}
    end

    # images ride along as raw JPEG instead of base64 inside the JSON payload, and
    # only after the layout they belong to, hence the trip through the mailbox
    @impl Kino.JS.Live
    def handle_info({:images, client_id}, ctx) do
      for {name, image} <- ctx.assigns.images do
        payload = {:binary, %{name: name}, image}

        if client_id,
          do: send_event(ctx, client_id, "image", payload),
          else: broadcast_event(ctx, "image", payload)
      end

      {:noreply, ctx}
    end

    def handle_info({:homex, :entities_changed}, ctx), do: {:noreply, ctx |> load() |> relayout()}

    # only the device sections move, the entities and their values are untouched
    def handle_info({:homex, :devices_changed}, ctx), do: {:noreply, relayout(ctx)}

    def handle_info({:homex, :state, descriptor, values, changes}, ctx) do
      broadcast_event(ctx, "card", card(descriptor, values, changes))
      ctx = assign(ctx, values: Map.put(ctx.assigns.values, descriptor.name, values))

      case values do
        %{image: image} when is_binary(image) ->
          broadcast_event(ctx, "image", {:binary, %{name: descriptor.name}, image})
          {:noreply, assign(ctx, images: Map.put(ctx.assigns.images, descriptor.name, image))}

        _ ->
          {:noreply, ctx}
      end
    end

    def handle_info(_msg, ctx), do: {:noreply, ctx}

    @impl Kino.JS.Live
    def handle_event("command", %{"name" => name, "cmd" => cmd}, ctx) do
      case Enum.find(ctx.assigns.descriptors, &(&1.name == name)) do
        %Homex.Descriptor{} = descriptor ->
          Homex.Entity.send_command(name, command(descriptor, cmd))

        nil ->
          :ok
      end

      {:noreply, ctx}
    end

    # the browser is a trust boundary, so a command may only touch the fields the
    # entity itself declares, matched as strings so no atom is built from input
    defp command(%Homex.Descriptor{fields: fields}, cmd) do
      for {field, _kind} <- fields, str = to_string(field), Map.has_key?(cmd, str), into: %{} do
        {field, clamp(str, cmd[str])}
      end
    end

    defp clamp("brightness", value) when is_number(value), do: value |> max(0) |> min(100)
    defp clamp(_field, value), do: value

    # a layout event rebuilds the browser from scratch, dropping the images with it
    defp relayout(ctx) do
      broadcast_event(ctx, "layout", layout(ctx))
      send(self(), {:images, nil})
      ctx
    end

    defp load(ctx) do
      descriptors = Homex.descriptors() |> Enum.sort_by(& &1.name)
      values = Map.new(descriptors, &{&1.name, Homex.Entity.snapshot(&1.name)})
      images = for {name, %{image: i}} <- values, is_binary(i), into: %{}, do: {name, i}

      assign(ctx, descriptors: descriptors, values: values, images: images)
    end

    defp layout(ctx) do
      devices = Homex.devices()

      sections =
        ctx.assigns.descriptors
        |> Enum.group_by(& &1.device)
        |> Enum.sort()
        |> Enum.map(fn {id, group} ->
          %{
            name: if(device = devices[id], do: device.name, else: to_string(id)),
            cards: Enum.map(group, &card(&1, ctx.assigns.values[&1.name]))
          }
        end)

      %{devices: sections}
    end

    defp card(descriptor, values, changes \\ %{}) do
      Kind.card(@kinds[descriptor.kind], descriptor, values, changes)
    end
  end
end
