defmodule Homex.Util do
  @moduledoc false

  @doc "Lowercases and collapses every run of non `a-z0-9` characters into one underscore"
  def slug(binary) when is_binary(binary) do
    binary
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
