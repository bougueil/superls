defmodule Superls.SearchCLI do
  @moduledoc false
  alias Superls.{
    MatchJaro,
    MatchSize,
    MatchDate,
    MatchTag,
    Prompt,
    Tag,
    Store,
    MergedIndex,
    StrFmt
  }

  @num_files_search_oldness Application.compile_env!(:superls, :num_files_search_oldness)
  @num_days_search_bydate Application.compile_env!(:superls, :num_days_search_bydate)

  @spec command_line(MergedIndex.t(), Keyword.t()) :: no_return()
  def command_line(mi, opts) do
    IO.write("""
    Enter a string to search a tag in store '#{Keyword.fetch!(opts, :store)}' (#{MergedIndex.get_num_tags(mi)} tags) or use the commands:
      q]uit, dt]upl_tags, ds]upl_size, xo|xn|ro|rn]date_old, xd|rd]bydate, s]ort_tags, m]etrics.
    """)

    cmd = IO.gets("-? ") |> String.trim_trailing()
    _ = command(mi, cmd, opts)
    command_line(mi, opts)
  end

  defp command(_merged_index, "", _opts),
    do: :ok

  defp command(_merged_index, "q", _opts) do
    IO.puts("CLI exits.")
    exit(:normal)
  end

  # metrics command
  defp command(mi, "m", opts) do
    max_freq_tags = 500
    store = Keyword.fetch!(opts, :store)
    passwd = Keyword.fetch!(opts, :passwd)
    info = MergedIndex.metrics(mi, max_freq_tags)

    IO.puts(String.pad_trailing("Volumes", 50) <> " " <> String.pad_trailing("Digest", 50))

    Store.volume_path_from_digests(store, passwd)
    |> Enum.map(fn {vol, digest} ->
      [
        {vol, :str, [:bright]},
        " ",
        {digest, :scr, []},
        "\n"
      ]
    end)
    |> StrFmt.to_string()
    |> IO.puts()

    IO.puts("""
    Details for the `#{store}` store :
    - Top #{max_freq_tags} frequent tags:\n#{info.most_frequent}
    - Tags: #{info.num_tags}
    - Files: #{info.num_files}
    """)

    if !Superls.Prompt.valid_default_no?("dump files names") do
      File.write!("/tmp/dump_superls", "")

      MergedIndex.files_index_from_tags(mi)
      |> Enum.each(fn {vol, files} ->
        File.write!("/tmp/dump_superls", "* Volume: #{vol}:\n", [:append])
        dump_files(files)
      end)

      IO.puts("files names stored in /tmp/dump_superls")
    end
  end

  defp command(mi, cmd, _opts) when cmd in ~w(xd rd) do
    today = Date.utc_today()

    date =
      Prompt.valid_default_or_new_input(
        "Enter a date like #{Date.to_string(today)}: ",
        today,
        &Date.from_iso8601!/1
      )

    ndays =
      Prompt.valid_default_or_new_input(
        "Confirm #{@num_days_search_bydate} days around the date (Y/new_value) ? ",
        @num_days_search_bydate,
        &Superls.string_to_numeric/1
      )

    result = MergedIndex.search_bydate(mi, cmd, date, ndays)

    [MatchDate.to_string(result, cmd), "[CLI found #{MatchDate.size(result)} result(s)]"]
    |> IO.puts()
  end

  defp command(mi, cmd, _opts) when cmd in ~w(xo xn ro rn) do
    nentries =
      Prompt.valid_default_or_new_input(
        "Confirm display first #{@num_files_search_oldness} entries (Y/new_value) ? ",
        @num_files_search_oldness,
        &Superls.string_to_numeric/1
      )

    result = MergedIndex.search_oldness(mi, cmd, nentries)

    [MatchDate.to_string(result, cmd), "[CLI found #{MatchDate.size(result)} result(s)]"]
    |> IO.puts()
  end

  defp command(mi, "ds", _opts) do
    IO.write("group files with similar size, this may take a while ...\r")

    result =
      MergedIndex.search_similar_size(mi)

    [MatchSize.to_string(result), "[CLI found #{MatchSize.size(result)} result(s)]"] |> IO.puts()
  end

  defp command(mi, "dt", _opts) do
    IO.write("group files with similar tags, this may take a while ...\r")

    result = MergedIndex.search_duplicated_tags(mi)

    [MatchJaro.to_string(result), "[CLI found #{MatchJaro.size(result)} result(s)]"] |> IO.puts()
  end

  # @limit_top_tags 500
  defp command(mi, "s", _opts) do
    tag_freqs = MergedIndex.tag_freq(mi)

    tags_by_occur =
      Enum.reduce(tag_freqs, %{}, fn {tag, count}, acc ->
        Map.get_and_update(acc, count, fn
          nil ->
            {nil, [tag]}

          tags ->
            {tags, [tag | tags]}
        end)
        |> elem(1)
      end)
      |> Map.delete(1)
      |> Enum.to_list()
      |> Enum.sort_by(fn {count, _} -> count end, &>/2)

    count = map_size(tag_freqs)

    [
      {"Number of tags: #{count}", :str, []},
      "\n",
      {"Occur.  Tags", :str, []},
      "\n",
      for {count, tags} <- tags_by_occur do
        [
          {count, :str, [:light_magenta, :reverse]},
          "  ",
          for tag <- tags do
            [{tag, :str, [:bright]}, "  "]
          end,
          "\n"
        ]
      end
    ]
    |> StrFmt.to_string()
    |> IO.puts()
  end

  defp command(mi, user_input, _opts) when byte_size(user_input) > 1 do
    {result, user_tags} = Tag.search_matching_tags(mi, user_input)

    user_tags =
      user_tags |> Enum.map(&{&1, :str, [:bright]}) |> Enum.intersperse(" * ") |> StrFmt.puts()

    IO.puts([
      MatchTag.to_string(result),
      "[CLI found #{MatchTag.size(result)} result(s) for #{user_tags}]"
    ])
  end

  defp command(_merged_index, user_input, _opts) do
    IO.puts("Unrecognized command: \"#{user_input}\"")
  end

  defp dump_files(files) do
    for {fp, finfo} <- files,
        do:
          File.write!(
            "/tmp/dump_superls",
            StrFmt.to_string([{finfo.size, :sizeb, []}, " ", {fp, :str, []}, "\n"]),
            [:append]
          )
  end
end
