defmodule Superls.SearchCLI do
  @moduledoc false
  alias Superls.{Api, Tag, Prompt, MatchJaro, MatchSize}

  @num_files_search_oldness Application.compile_env!(:superls, :num_files_search_oldness)
  @num_days_search_bydate Application.compile_env!(:superls, :num_days_search_bydate)

  def command_line(merged_index, store_name_or_path) do
    IO.write("""
      #{map_size(merged_index)} tags in '#{store_name_or_path}' - enter a string to search tags or use the commands:
      q]uit, dt]upl_tags, ds]upl_size, xo|xn|ro|rn]date_old, xd|rd]bydate, s]ort_tags.
    """)

    cmd = IO.gets("-? ") |> String.trim_trailing()
    command(merged_index, cmd)
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
      Prompt.confirm_input_default(
        "Enter a date like #{Date.to_string(today)}: ",
        today,
        &Date.from_iso8601!/1,
        true
      )

    ndays =
      Prompt.confirm_input_default(
        "Confirm #{@num_days_search_bydate} days around the date (Y/new_value) ? ",
        @num_days_search_bydate,
        &Superls.string_to_numeric/1,
        true
      )

    Api.search_bydate(merged_index, cmd, date, ndays)
  end

  defp command(merged_index, cmd) when cmd in ~w(xo xn ro rn) do
    nentries =
      Prompt.confirm_input_default(
        "Confirm display first #{@num_files_search_oldness} entries (Y/new_value) ? ",
        @num_files_search_oldness,
        &Superls.string_to_numeric/1,
        true
      )

    Api.search_oldness(merged_index, cmd, nentries)
  end

  defp command(merged_index, "ds") do
    merged_index
    |> Api.search_similar_size()
    |> MatchSize.pretty_print_result()
  end

  defp command(merged_index, "dt") do
    merged_index
    |> Api.search_duplicated_tags()
    |> MatchJaro.pretty_print_result()
  end

  defp command(merged_index, "s") do
    res = Tag.tag_freq(merged_index)

    IO.puts(
      "[{tag, {num_occur, from_same_host?}}, ..]\n#{inspect(res, pretty: true, limit: :infinity)}"
    )
  end

  defp command(merged_index, user_input) do
    res =
      Api.search_from_index(user_input, merged_index)
      |> search_output_friendly()

    IO.puts(
      "CLI found \r#{length(res)} result(s) for \"#{String.trim(user_input, "\n")}\" ------------------"
    )
  end

  # def command_line(merged_index, store_name_or_path) do
  #   IO.write("""
  #     #{map_size(merged_index)} tags in '#{store_name_or_path}' - enter any string like `1967 twice`, q]uit or
  #     s]ort_tags, `dt]upl_tags, ds]upl_size, xo|xn|ro|rn]date_old, xd|rd]bydate.
  #   """)

  #   user_tags = IO.gets("-? ") |> String.trim_trailing()

  #   case user_tags do
  #     "" ->
  #       command_line(merged_index, store_name_or_path)

  #     "q" ->
  #       IO.puts("CLI exits.")

  #     "s" ->
  #       res = Tag.tag_freq(merged_index)

  #       IO.puts(
  #         "[{tag, {num_occur, from_same_host?}}, ..]\n#{inspect(res, pretty: true, limit: :infinity)}"
  #       )

  #       command_line(merged_index, store_name_or_path)

  #     "dt" ->
  #       merged_index
  #       |> Api.search_duplicated_tags()
  #       |> MatchJaro.pretty_print_result()

  #       command_line(merged_index, store_name_or_path)

  #     "ds" ->
  #       merged_index
  #       |> Api.search_similar_size()
  #       |> MatchSize.pretty_print_result()

  #       command_line(merged_index, store_name_or_path)

  #     cmd when cmd in ~w(xo xn ro rn) ->
  #       nentries =
  #         Prompt.confirm_numeric_default(
  #           "Confirm display first #{@num_files_search_oldness} entries (Y/new_value) ? ",
  #           @num_files_search_oldness,
  #           true
  #         )

  #       Api.search_oldness(merged_index, cmd, nentries)
  #       command_line(merged_index, store_name_or_path)

  #     cmd when cmd in ~w(xd rd) ->
  #       today = Date.utc_today()

  #       date =
  #         Prompt.confirm_date_default("Enter a date like #{Date.to_string(today)}: ", today, true)

  #       ndays =
  #         Prompt.confirm_numeric_default(
  #           "Confirm #{@num_days_search_bydate} days around the date (Y/new_value) ? ",
  #           @num_days_search_bydate,
  #           true
  #         )

  #       Api.search_bydate(merged_index, cmd, date, ndays)
  #       command_line(merged_index, store_name_or_path)

  #     # USER entered tags e.g. `1916 world wars`
  #     user_input ->
  #       res =
  #         Api.search_from_index(user_input, merged_index)
  #         |> search_output_friendly()

  #       IO.puts(
  #         "CLI found \r#{length(res)} result(s) for \"#{String.trim(user_input, "\n")}\" ------------------"
  #       )

  #       command_line(merged_index, store_name_or_path)
  #   end
  # end

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
