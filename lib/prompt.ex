defmodule Superls.Prompt do
  @moduledoc false

  def prompt?(prompt, confirm? \\ false) do
    (Code.loaded?(Mix) && Mix.env() == :test) || !confirm? || yes?(IO.gets(prompt))
  end

  def yes?(string) when is_binary(string),
    do: String.trim(string) in ["", "y", "Y", "yes", "YES", "Yes"]
end
