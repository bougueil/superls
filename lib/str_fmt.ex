defmodule Superls.StrFmt do
  require Logger
  import Kernel, except: [to_string: 1]

  @moduledoc """
  ```elixir
  iex> StrFmt.to_string [{12000, :sizeb, [:bright]}]
  "\e[1m  11.7K\e[0m"
  ```

  or composable form :

  ```elixir
  iex> [ [str_fmt1, str_fmt2], 
         str_fmt3
       ] |> StrFmt.to_string()
  ```

  str_fmt_unit                        | output for a 8 columns terminal
  :---------------------------------- | :---------
  `"abc"`                             | `"abc"`
  `[{"abc", :str, [:blue]}]`          | `"\e[34mabc\e[0m"`
  `[{123, :str, [:blue]}]`            | `"\e[34m123\e[0m"`
  `[{12000, :sizeb, []}]`             | `"  11.7K"`  # could be B, K, M and G.
  `[{1696153262, :date, [:blue]}]`    | `"\e[34m2023-10-01\e[0m"`
  `[{1696153262, :datetime, []}]`     | `"23-10-01 09:41:02"`
  `[{"9char-str", {:scr,50}, []}]`    | `"9..r"`     # 50% of 9 chars screen
  `[{"9char-str", :scr, []}]`         | `"9ch..str"` # equiv. of {:scr, 100}
  `[{"foo_", :padr, []}]`             | `"foo_____"`
  `[{"_", :padl, [:red]}]`            | `"\e[31m_____\e[0m"`
  """

  @type str_fmt_unit() ::
          String.t()
          | {String.t() | :atom | charlist() | number(), :str, IO.ANSI.ansidata()}
          | {integer(), :sizeb, IO.ANSI.ansidata()}
          | {posix_time :: integer(), :date, IO.ANSI.ansidata()}
          | {posix_time :: integer(), :datetime, IO.ANSI.ansidata()}
          | {String.t(), :scr, IO.ANSI.ansidata()}
          | {String.t(), {:scr, number()}, IO.ANSI.ansidata()}
          | {String.t(), :padl, IO.ANSI.ansidata()}
          | {String.t(), :padr, IO.ANSI.ansidata()}
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
  - basic types interpolation

    `str`
  - newline

    `"\n"` 
  """
  @spec to_string(str_fmt :: t()) :: formatted_str :: String.t()
  def to_string(str_fmt) when is_list(str_fmt) do
    ncols = ncols()

    # not optimal best to keep a IOList in acc
    # but don't know how to compute the length of a IOList without ascii color chars.
    str_fmt
    |> List.flatten()
    |> Enum.reduce({"", 0}, fn
      {val, fmt_type, ansidata}, {acc, acclen} ->
        fmt = IO.ANSI.format(ansidata ++ [fmt_type(fmt_type, val, acclen, ncols)])
        # List.ascii_printable?
        {fmt, len_fmt} =
          try do
            text_length(fmt)
          rescue
            err ->
              Logger.warning("error: " <> inspect(err) <> " wrong chars : " <> inspect(fmt))
              text_length(IO.ANSI.format(ansidata))
          end

        {acc <> fmt, acclen + len_fmt}

      "\n", {acc, _acclen} ->
        {acc <> "\n", 0}

      str, {acc, acclen} when is_binary(str) ->
        {fmt, len_fmt} = text_length(str)

        {acc <> fmt, acclen + len_fmt}
    end)
    |> elem(0)
  end

  @doc "puts(fmt) convenience for `to_string(fmt) |> IO.puts()`"
  @spec puts(str_fmt :: t()) :: :ok
  def puts(str_fmt) when is_list(str_fmt), do: __MODULE__.to_string(str_fmt) |> IO.puts()

  defp fmt_type(:datetime, val, _acclen, _ncols),
    do: val |> DateTime.from_unix!() |> Calendar.strftime("%y-%m-%d %H:%M:%S")

  defp fmt_type(:date, val, _acclen, _ncols),
    do: val |> DateTime.from_unix!() |> DateTime.to_date() |> Date.to_string()

  defp fmt_type(:str, val, _acclen, _ncols), do: "#{val}"

  defp fmt_type(:sizeb, val, _acclen, _ncols), do: pp_sz(val)

  defp fmt_type(:scr, val, acclen, ncols) when is_binary(val),
    do: shorten_text(val, ncols - acclen)

  defp fmt_type({:scr, pcent}, val, acclen, ncols)
       when is_integer(pcent) and pcent <= 100 and pcent >= 0 and is_binary(val),
       do: shorten_text(val, min(ncols - acclen, div(ncols * pcent, 100)))

  defp fmt_type(:padr, val, acclen, ncols) when is_binary(val),
    do: str_fmt_pad(&String.last/1, &String.pad_trailing/3, val, acclen, ncols)

  defp fmt_type(:padl, val, acclen, ncols) when is_binary(val),
    do: str_fmt_pad(&String.first/1, &String.pad_leading/3, val, acclen, ncols)

  defp fmt_type(type, _val, acclen, ncols) do
    fmt_type(:scr, "invalid str_fmt type: `#{inspect(type)}`", acclen, ncols)
  end

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

  def text_length(txt) do
    str = Kernel.to_string(txt)
    {str, Regex.replace(~r/\e\[[0-9;]*[a-zA-Z]/, str, "") |> :string.length()}
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
end
