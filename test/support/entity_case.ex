defmodule Homex.EntityCase do
  @moduledoc """
  Test case for entity tests: subscribes the test process so it receives
  `{:homex, :state, descriptor, values, changes}` and
  `{:homex, :entities_changed}`.

  There is one global topic, so an `async: true` module sees the broadcasts of
  every other module running at the same time. Match on the descriptor name in
  `refute_receive`, or set `async: false` when the message carries no name.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Homex.{Descriptor, Entity}
    end
  end

  setup do
    Homex.subscribe()
    :ok
  end
end
