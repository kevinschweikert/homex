defmodule Homex.EntityCase do
  @moduledoc """
  Test case for entity tests: attaches the test process to the shared test
  adapter (started in `test_helper.exs`) to receive `{:publish_state, _, _}`
  messages from entities started by this test.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Homex.{Descriptor, Entity}
    end
  end

  setup do
    Homex.Adapter.Test.attach()
    :ok
  end
end
