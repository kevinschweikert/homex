defmodule Homex.EntityTest do
  use ExUnit.Case, async: true

  alias Homex.Entity

  describe "struct helper" do
    test "register_handler/3" do
      entity =
        %Entity{}
        |> Entity.register_handler(:test, &Function.identity/1)

      assert :test in entity.keys
      assert %{test: nil} = entity.values
      assert %{test: _} = entity.handlers
    end

    test "put_change/3" do
      entity =
        %Entity{}
        |> Entity.register_handler(:test, &Function.identity/1)
        |> Entity.put_change(:test, 10)

      assert %{test: 10} = entity.changes
    end

    test "handle_changes/1" do
      entity =
        %Entity{}
        |> Entity.register_handler(:test, fn val -> send(self(), val) end)
        |> Entity.put_change(:test, 10)
        |> Entity.execute_change()

      assert_receive 10
      assert Map.keys(entity.changes) == []

      entity
      |> Entity.put_change(:test, 10)
      |> Entity.execute_change()

      refute_receive 10
    end
  end
end
