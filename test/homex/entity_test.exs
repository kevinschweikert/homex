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

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "test-switch"
  end

  describe "new/1" do
    test "accepts a bare module, defaulting name and impl to it" do
      assert %Entity{name: TestSwitch, impl: TestSwitch} = Entity.new(TestSwitch)
    end

    test "accepts a keyword list with name and impl" do
      assert %Entity{name: :my_switch, impl: TestSwitch} =
               Entity.new(name: :my_switch, impl: TestSwitch)
    end

    test "returns nil for invalid input" do
      assert Entity.new(name: :missing_impl) == nil
      assert Entity.new(%{}) == nil
    end
  end

  describe "valid?/1" do
    test "accepts bare modules implementing the behaviour" do
      assert Entity.valid?(TestSwitch)
      refute Entity.valid?(Enum)
    end
  end

  describe "execute_change/1" do
    test "existing values should stay" do
      entity =
        %Entity{}
        |> Entity.register_handler(:test, &Function.identity/1, :bar)
        |> Entity.register_handler(:test_two, &Function.identity/1, :foo)
        |> Entity.put_change(:test, 10)
        |> Entity.execute_change()

      assert entity.values.test == 10
      assert entity.values.test_two == :foo
    end
  end
end
