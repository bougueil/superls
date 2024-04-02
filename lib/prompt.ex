defmodule Superls.Prompt do
  @moduledoc false

  def prompt_new_value(prompt, default, input_hdlr, prompted? \\ false) do
    new_value = running_test?() || !prompted? || yes_new_value(IO.gets(prompt))

    case new_value do
      true ->
        default

      _ ->
        input_hdlr.(String.trim_trailing(new_value))
    end
  end

  def yes_new_value(string) when is_binary(string),
    do: String.trim(string) in ["", "y", "Y", "yes", "YES", "Yes"] || string

  # prompt the `prompt` message and returns true or the entered value
  def prompt(prompt, prompted? \\ false),
    do: running_test?() || !prompted? || yes(IO.gets(prompt))

  # returns true or the entered value
  def yes(string) when is_binary(string),
    do: String.trim(string) in ["", "y", "Y", "yes", "YES", "Yes"]

  defp running_test?,
    do: Code.loaded?(HelperTest)
end
