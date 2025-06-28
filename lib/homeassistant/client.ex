defmodule Homeassistant.Client do
  @moduledoc """
  The MQTT client
  """

  def start_link(opts) do
    :emqtt.start_link(opts)
  end

  def connect(server) do
    :emqtt.connect(server)
  end

  def disconnect(server) do
    :emqtt.disconnect(server)
  end

  def publish(server, topic, payload, opts \\ [])

  def publish(server, topic, payload, opts) when is_binary(payload) do
    :emqtt.publish(server, topic, payload, opts)
  end

  def publish(server, topic, payload, opts) do
    with {:ok, data} <- Jason.encode(payload) do
      :emqtt.publish(server, topic, data, opts)
    end
  end

  def subscribe(server, topic) do
    :emqtt.subscribe(server, topic)
  end

  def unsubscribe(server, topic) do
    :emqtt.unsubscribe(server, topic)
  end
end
