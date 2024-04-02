defmodule Superls.SearchCLI do
  @moduledoc false
  alias Superls.{MatchJaro, MatchSize, Prompt, Tag}

  @num_files_search_oldness Application.compile_env!(:superls, :num_files_search_oldness)
  @num_days_search_bydate Application.compile_env!(:superls, :num_days_search_bydate)

  def command_line(merged_index, store_name_or_path) do
    IO.write("""
      #{map_size(merged_index)} tags in '#{store_name_or_path}' - enter a string to search tags or use the commands:
      q]uit, dt]upl_tags, ds]upl_size, xo|xn|ro|rn]date_old, xd|rd]bydate, s]ort_tags.
    """)

    cmd = IO.gets("-? ") |> String.trim_trailing()
    _ = command(merged_index, cmd)
    command_line(merged_index, store_name_or_path)
  end

  defp command(_merged_index, ""),
    do: :ok

  defp command(_merged_index, "q") do
    IO.puts("CLI exits.")
    exit(:normal)
  end

  defp command(merged_index, cmd) when cmd in ~w(xd rd) do
    today = Date.utc_today()

    date =
      Prompt.prompt_new_value(
        "Enter a date like #{Date.to_string(today)}: ",
        today,
        &Date.from_iso8601!/1,
        true
      )

    ndays =
      Prompt.prompt_new_value(
        "Confirm #{@num_days_search_bydate} days around the date (Y/new_value) ? ",
        @num_days_search_bydate,
        &Superls.string_to_numeric/1,
        true
      )

    Tag.search_bydate(merged_index, cmd, date, ndays)
  end

  defp command(merged_index, cmd) when cmd in ~w(xo xn ro rn) do
    nentries =
      Prompt.prompt_new_value(
        "Confirm display first #{@num_files_search_oldness} entries (Y/new_value) ? ",
        @num_files_search_oldness,
        &Superls.string_to_numeric/1,
        true
      )

    Tag.search_oldness(merged_index, cmd, nentries)
  end

  defp command(merged_index, "ds") do
    IO.write("searching by similar file size, this may take a while ...\r")

    merged_index
    |> Tag.search_similar_size()
    |> MatchSize.pretty_print_result()
  end

  defp command(merged_index, "dt") do
    IO.write("searching by similar tags, this may take a while ...\r")

    merged_index
    |> Tag.search_duplicated_tags()
    |> MatchJaro.pretty_print_result()
  end

  defp command(merged_index, "s") do
    res = Tag.tag_freq(merged_index)

    IO.puts(
      "[{tag, {num_occur, from_same_host?}}, ..]\n#{inspect(res, pretty: true, limit: :infinity)}"
    )
  end

  defp command(merged_index, user_input) when byte_size(user_input) > 1 do
    res =
      Tag.search_matching_tags(merged_index, user_input)
      |> search_output_friendly()

    IO.puts(
      "CLI found \r#{length(res)} result(s) for \"#{String.trim(user_input, "\n")}\" ------------------"
    )
  end

  defp command(_merged_index, user_input) do
    IO.puts("Unrecognized command: \"#{user_input}\"")
  end

  defp search_output_friendly(search_res) do
    for {file, vol} <- search_res do
      (IO.ANSI.bright() <>
         Path.basename(file.name) <>
         IO.ANSI.reset() <>
         "\t" <>
         Superls.pp_sz(file.size) <>
         "\t" <>
         vol <> "/" <> Path.dirname(file.name) <> IO.ANSI.reset())
      |> IO.puts()
    end
  end
end
