defmodule Superls.StrFmt do
  @moduledoc """
  ```elixir
  iex> Superls.StrFmt.to_string [{12000, :sizeb, [:bright]}]
  "\e[1m  11.7K\e[0m"
  ```

  or composable form :

  ```elixir
  iex> [ [str_fmt1, str_fmt2], 
         str_fmt3
       ] |> Superls.StrFmt.to_string()
  ```

  str_fmt_unit                                        | output for a 8 columns terminal
  :-------------------------------------------------- | :---------
  `"abc"`                                             | `"abc"`
  `[{"abc", :str, [:blue]}]`                          | `"\e[34mabc\e[0m"`
  `[{123, :str, [:blue]}]`                            | `"\e[34m123\e[0m"`
  `[{{5, "abc"}, :str, [:blue]}]`                     | `"\e[34m  abc\e[0m"`
  `[{{"link", "http://ubuntu.com/"}, :link, [:red]}]` | `"\e[31m\e]8;;http://ubuntu.com/\e\\link\e]8;;\e\\\e[0m"`
  `[{12000, :sizeb, []}]`                             | `"  11.7K"`  # could be B, K, M and G.
  `[{1696153262, :date, [:blue]}]`                    | `"\e[34m2023-10-01\e[0m"`
  `[{1696153262, :datetime, []}]`                     | `"23-10-01 09:41:02"`
  `[{"9char-str", {:scr,50}, []}]`                    | `"9..r"`     # 50% of 9 chars screen
  `[{"9char-str", :scr, []}]`                         | `"9ch..str"` # equiv. of {:scr, 100}
  `[{"foo_", :padr, []}]`                             | `"foo_____"`
  `[{"_", :padl, [:red]}]`                            | `"\e[31m_____\e[0m"`
  """

  @type str_fmt_unit() ::
          String.t()
          | {String.t() | :atom | charlist() | number(), :str, IO.ANSI.ansidata()}
          | {{lpad :: integer(), String.t() | :atom | charlist() | number()}, :str,
             IO.ANSI.ansidata()}
          | {integer(), :sizeb, IO.ANSI.ansidata()}
          | {posix_time :: integer(), :date, IO.ANSI.ansidata()}
          | {posix_time :: integer(), :datetime, IO.ANSI.ansidata()}
          | {String.t(), :scr, IO.ANSI.ansidata()}
          | {String.t(), {:scr, number()}, IO.ANSI.ansidata()}
          | {String.t(), :padl, IO.ANSI.ansidata()}
          | {String.t(), :padr, IO.ANSI.ansidata()}
          | {{link :: String.t(), uri :: String.t()}, :link, IO.ANSI.ansidata()}
          | [str_fmt_unit()]

  @type t :: [str_fmt_unit()]

  @doc """
  Format the `str_fmt` into a string.

      iex> StrFmt.to_string [{12000, :sizeb, [:bright]}]
      "\e[1m  11.7K\e[0m"

  The transformations are :

  - colors

    see `IO.ANSI`.
  - padding to a ncols terminal

    `padr`  `padl`     
  - human readable bytes B, K, M, G

    `sizeb`
  - shorten txt, may add ellipsis if txt length > ncols

    `scr`  
  - shorten percent txt, may add ellipsis if txt length > 44% of ncols

    `{scr, 44}`  
  - human readable date, datetime (posix)

    `date` `datetime`
  - link to URI

    `link`
  - basic types interpolation

    `str`

  - left padding basic types interpolation

    `{lpad_width, str}` # same as String.pad_leading(str, pad_width, " ")

  - newline

    `"\n"` 
  """
  @spec to_string(str_fmt :: t()) :: formatted_str :: String.t()
  def to_string(str_fmt) when is_list(str_fmt), do: ansi_assemble(str_fmt) |> elem(0)

  @doc "assemble `str_fmt` into a string and associated length"
  @spec ansi_assemble(str_fmt :: t()) :: {assembled :: String.t(), len :: integer()}
  def ansi_assemble(str_fmt) when is_list(str_fmt) do
    ncols = ncols()

    str_fmt
    |> List.flatten()
    |> Enum.reduce({"", 0}, fn
      {val, fmt_type, ansidata}, {acc, acclen} ->
        {fmt_len, fmt} = type_fmt(fmt_type, val, acclen, ncols)
        fmt = IO.ANSI.format(ansidata ++ [fmt]) |> IO.chardata_to_string()
        {acc <> fmt, acclen + fmt_len}

      "\n", {acc, _acclen} ->
        {acc <> "\n", 0}

      str, {acc, acclen} when is_binary(str) ->
        {acc <> str, acclen + :string.length(str)}
    end)
  end

  @doc "puts(fmt) convenience for `to_string(fmt) |> IO.puts()`"
  @spec puts(str_fmt :: t()) :: :ok
  def puts(str_fmt) when is_list(str_fmt), do: __MODULE__.to_string(str_fmt) |> IO.puts()

  defp type_fmt(:datetime, val, _acclen, _ncols),
    do: val |> DateTime.from_unix!() |> Calendar.strftime("%y-%m-%d %H:%M:%S") |> type_fmt_str()

  defp type_fmt(:date, val, _acclen, _ncols),
    do: val |> DateTime.from_unix!() |> DateTime.to_date() |> Date.to_string() |> type_fmt_str()

  defp type_fmt(:str, {lpad_width, val}, _acclen, _ncols),
    do: String.pad_leading("#{val}", lpad_width) |> type_fmt_str()

  defp type_fmt(:str, val, _acclen, _ncols), do: "#{val}" |> type_fmt_str()

  defp type_fmt(:link, {link, uri}, _acclen, _ncols), do: {link, uri} |> type_fmt_link()

  defp type_fmt(:sizeb, val, _acclen, _ncols), do: pp_sz(val) |> type_fmt_str()

  defp type_fmt(:scr, val, acclen, ncols) when is_binary(val),
    do: shorten_text(val, ncols - acclen) |> type_fmt_str()

  defp type_fmt({:scr, pcent}, val, acclen, ncols)
       when is_integer(pcent) and pcent <= 100 and pcent >= 0 and is_binary(val),
       do: shorten_text(val, min(ncols - acclen, div(ncols * pcent, 100))) |> type_fmt_str()

  defp type_fmt(:padr, val, acclen, ncols) when is_binary(val),
    do: str_fmt_pad(&String.last/1, &String.pad_trailing/3, val, acclen, ncols) |> type_fmt_str()

  defp type_fmt(:padl, val, acclen, ncols) when is_binary(val),
    do: str_fmt_pad(&String.first/1, &String.pad_leading/3, val, acclen, ncols) |> type_fmt_str()

  defp type_fmt(type, _val, acclen, ncols),
    do: type_fmt(:scr, "invalid str_fmt type: `#{inspect(type)}`", acclen, ncols)

  defp type_fmt_str(str), do: {:string.length(str), str}

  defp type_fmt_link({link, uri}), do: {:string.length(link), link(link, uri)}

  @doc false
  def pp_sz(size) when is_integer(size) do
    cond do
      size > 10 * 1024 * 1024 * 1024 ->
        "#{:erlang.float_to_binary(size / 1024 / 1024 / 1024, decimals: 1)}G"

      size > 10 * 1024 * 1024 ->
        "#{:erlang.float_to_binary(size / 1024 / 1024, decimals: 1)}M"

      size > 10 * 1024 ->
        "#{:erlang.float_to_binary(size / 1024, decimals: 1)}K"

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

  defp str_fmt_pad(last_char, pad, val, acclen, ncols) do
    len_left = ncols - acclen
    last_c = last_char.(val)

    if len_left > 1 and last_c do
      pad.(val, len_left, last_c)
    else
      val
    end
  end

  @doc "Returns the terminal number of columns."
  @spec ncols() :: integer()
  if Mix.env() == :test do
    def ncols(), do: 40
  else
    def ncols() do
      case :io.columns() do
        {:error, _} -> 40
        {:ok, ncols} -> ncols
      end
    end
  end

  defp link(link, uri), do: "\e]8;;#{uri}\e\\#{link}\e]8;;\e\\"
end
