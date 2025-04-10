defmodule Superls.StrFmt do
  @moduledoc """
  Format / pad / colorize text to fit in the terminal screen.

      iex> StrFmt.pp [{12000, :sizeb, [:bright]}] == "\e[1m  11.7K\e[0m"


  str_fmt_spec                      | output
  :-------------------------------- | :---------
  `["abc"]`                         | `"abc"`
  `[{"abc", :void, [:blue]}]`       | `"\e[34mabc\e[0m"`
  `[{123, :void, [:blue]}]`         | `"\e[34m123\e[0m"`
  `[{12000, :sizeb, []}]`           | `"  11.7K"`  # could be B, K, M and G.
  `[{1696153262, :date, [:blue]}]`  | `"\e[34m2023-10-01\e[0m"`
  `[{1696153262, :datetime, []}]`   | `"23-10-01 09:41:02"`
  `[{"9char-str", {:fit,50}, []}]`  | `"9..r"`     # 50%  of a 8c screen_width
  `[{"9char-str", :fit_width, []}]` | `"9ch..str"` # equiv. of {:fit, 100}
  """

  @type str_fmt_spec() ::
          String.t()
          | {String.t() | :atom | charlist() | number(), :void, IO.ANSI.ansidata()}
          | {integer(), :sizeb, IO.ANSI.ansidata()}
          | {integer(), :date, IO.ANSI.ansidata()}
          | {integer(), :datetime, IO.ANSI.ansidata()}
          | {String.t(), :fit_width, IO.ANSI.ansidata()}
          | {String.t(), {:fit, number()}, IO.ANSI.ansidata()}

  @type t :: [str_fmt_spec()]

  @doc """
  Format the `str_fmt_specs` list into a string.

      iex> StrFmt.pp [{12000, :sizeb, [:bright]}]
      "\e[1m  11.7K\e[0m"
  """
  @spec pp(str_fmt_specs :: t()) :: formatted_str :: String.t()
  def pp(str_fmt_specs) when is_list(str_fmt_specs) do
    screen_w = screen_w()

    Enum.reduce(str_fmt_specs, "", fn
      {val, fmt_type, ansidata}, acc when is_binary(acc) ->
        acc <> to_string(IO.ANSI.format(ansidata ++ [fmt_type(fmt_type, val, acc, screen_w)]))

      str, acc when is_binary(str) ->
        acc <> str
    end)
  end

  @allowed_fmt ":date, :datetime, :void, :sizeb, :fit_width, {:fit, screen_percent}"

  defp fmt_type(fmt_type, val, acc, screen_w) do
    case fmt_type do
      :datetime ->
        val |> DateTime.from_unix!() |> Calendar.strftime("%y-%m-%d %H:%M:%S")

      :date ->
        val |> DateTime.from_unix!() |> DateTime.to_date() |> Date.to_string()

      :void ->
        "#{val}"

      :sizeb ->
        pp_sz(val)

      :fit_width ->
        shorten_text(val, screen_w - String.length(acc))

      {:fit, pcent} when is_integer(pcent) and pcent < 101 and pcent >= 0 ->
        shorten_text(val, div(screen_w * pcent, 100))

      _err ->
        Superls.halt("Unrecognised format: #{inspect(fmt_type)}, choose btw: #{@allowed_fmt} .")
    end
  end

  @doc false
  def pp_sz(size) when is_integer(size) do
    cond do
      size > 10 * 1024 * 1024 * 1024 ->
        "#{div(size, 1024 * 1024 * 102) / 10}G"

      size > 10 * 1024 * 1024 ->
        "#{div(size, 1024 * 102) / 10}M"

      size > 10 * 1024 ->
        "#{div(size, 102) / 10}K"

      true ->
        "#{size}B"
    end
    |> String.pad_leading(7)
  end

  defp shorten_text(str, len_left) do
    cond do
      len_left <= 0 ->
        ""

      String.length(str) <= len_left ->
        str

      true ->
        mid = max(1, div(len_left, 2) - 1)
        String.slice(str, 0..(mid - 1)) <> ".." <> String.slice(str, -mid..-1)
    end
  end

  if Mix.env() == :test do
    defp screen_w(), do: 40
  else
    defp screen_w(), do: :io.columns() |> elem(1)
  end
end
