defmodule Superls.Prompt do
  @moduledoc false

  def confirm_input_default(prompt, default, input_hdlr, confirm? \\ false) do
    case prompt(prompt, confirm?) do
      true ->
        default

      new_value ->
        input_hdlr.(String.trim_trailing(new_value))
    end
  end

  # prompt the `prompt` message and returns true or the entered value
  def prompt(prompt, confirm? \\ false),
    do: (Code.loaded?(Mix) && Mix.env() == :test) || !confirm? || yes(IO.gets(prompt))

  # returns true or the entered value
  def yes(string) when is_binary(string),
    do: String.trim(string) in ["", "y", "Y", "yes", "YES", "Yes"] || string
end
