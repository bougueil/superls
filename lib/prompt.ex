defmodule Superls.Prompt do
  @moduledoc false

  @doc """
  return true if user enter Y/y/RETURN
  """
  @spec valid_default_yes?(String.t()) :: boolean()
  def valid_default_yes?(msg), do: valid_default_no_yes_prompt?(msg, :yes)

  @doc """
  return true if user enter N/n/RETURN
  """
  @spec valid_default_no?(String.t()) :: boolean()
  def valid_default_no?(msg), do: valid_default_no_yes_prompt?(msg, :no)

  @spec valid_default_or_new_input(String.t(), any(), (String.t() -> any())) :: boolean() | any()
  def valid_default_or_new_input(prompt, default, input_hdlr) do
    new_value = yes_or_input(Superls.gets(prompt, "y"))

    case new_value do
      true ->
        default

      _ ->
        input_hdlr.(String.trim_trailing(new_value))
    end
  end

  defp valid_default_no_yes_prompt?(prompt, :yes) do
    match?(
      <<n::size(8), _::binary>> when n not in [?n, ?N],
      Superls.gets(prompt <> " [Y/n] ? ", "y")
    )
  end

  defp valid_default_no_yes_prompt?(prompt, :no) do
    match?(
      <<n::size(8), _::binary>> when n not in [?y, ?Y],
      Superls.gets(prompt <> " [N/y] ? ", "y")
    )
  end

  defp yes_or_input(string) when is_binary(string),
    do: String.trim(string) in ["", "y", "Y", "yes", "YES", "Yes"] || string
end
