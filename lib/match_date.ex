defmodule Superls.MatchDate do
  @day_seconds 3600 * 24
  @moduledoc false
  # list oldest / newest files according to mtime / atime

  @doc ~S"""
  returns files between date from a list of files according to cmd:
  - `xd`: created / modified date
  - `rd`: accessed date
  """
  def search_bydate(files, cmd, date, ndays) when cmd in ~w(xd rd) do
    {_sorter, field} = sorter_field(cmd)

    # mtime : 1696153262 ~U[2023-10-01 09:41:02Z]
    date_unix = Date.diff(date, ~D[1970-01-01]) * @day_seconds
    date_min = date_unix - ndays * @day_seconds
    date_max = date_unix + ndays * @day_seconds

    IO.puts(
      "search result files between #{from_unix!(date_min)} and #{from_unix!(date_max)} (#{ndays} days): "
    )

    Enum.reduce(files, [], fn e = {{f, _}, _}, acc ->
      if field.(f) >= date_min and f.mtime <= date_max do
        [e | acc]
      else
        acc
      end
    end)
    |> output_friendly(field)
  end

  @doc ~S"""
  returns the oldest or newest files from a list of files according to:
  - `xo`: created / modified oldest
  - `xn`: created / modified newest
  - `ro`: accessed oldest
  - `rn`: accessed newest
  the default number of returned files is set by the config parameter `:num_files`
  """
  def search_oldness(files, cmd, nentries) do
    {sorter, field} = sorter_field(cmd)

    IO.puts("search newest/oldest (#{cmd}) files, max: (#{nentries} files): ")

    Enum.sort(files, sorter)
    |> Enum.take(nentries)
    |> output_friendly(field)
  end

  @doc false
  def output_friendly(result, field) do
    for {{f, path}, _} <- result do
      (IO.ANSI.bright() <>
         Path.basename(f.name) <>
         IO.ANSI.reset() <>
         "\t" <>
         Superls.pp_sz(f.size) <>
         "\t" <>
         datetime_human_str(field.(f)) <>
         "\t" <>
         path <>
         "/" <>
         Path.dirname(f.name) <>
         IO.ANSI.reset())
      |> IO.puts()
    end
  end

  defp sorter_field(cmd) do
    case cmd do
      "xo" -> {fn {{a, _}, _}, {{b, _}, _} -> a.mtime < b.mtime end, & &1.mtime}
      "xn" -> {fn {{a, _}, _}, {{b, _}, _} -> a.mtime >= b.mtime end, & &1.mtime}
      "ro" -> {fn {{a, _}, _}, {{b, _}, _} -> a.atime < b.atime end, & &1.atime}
      "rn" -> {fn {{a, _}, _}, {{b, _}, _} -> a.atime >= b.atime end, & &1.atime}
      "xd" -> {nil, & &1.mtime}
      "rd" -> {nil, & &1.atime}
    end
  end

  defp from_unix!(posix) do
    DateTime.from_unix!(posix)
    |> DateTime.to_date()
    |> Date.to_string()
  end

  # defp date_human_str(posix_time),
  #   do: posix_time |> DateTime.from_unix!() |> DateTime.to_date() |> Date.to_string()

  defp datetime_human_str(posix_time),
    do: posix_time |> DateTime.from_unix!() |> DateTime.to_string()
end
