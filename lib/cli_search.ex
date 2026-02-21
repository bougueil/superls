defmodule Superls.CLI.Search do
  @moduledoc false
  alias Superls.{
    MatchJaro,
    MatchSize,
    MatchDate,
    MatchTag,
    Prompt,
    Store,
    MergedIndex,
    StrFmt
  }

  @num_files_search_oldness Application.compile_env!(:superls, :num_files_search_oldness)
  @num_days_search_bydate Application.compile_env!(:superls, :num_days_search_bydate)
  @superl_filenames "/tmp/superl_filenames"

  @spec start(MergedIndex.t(), Keyword.t()) :: no_return()
  def start(mi, opts) do
    spawn(fn ->
      :ok = :io.setopts(expand_fun: &expand_fun/1)
      loop(mi, opts)
    end)
  end

  @search_cmds ~w(ds dt m rd rn ro s xd xn xo)c

  # If line is empty, we list all available commands
  defp expand_fun(~c""), do: {:yes, ~c"", @search_cmds}
  defp expand_fun(curr), do: expand_fun(:lists.reverse(curr), @search_cmds)

  defp expand_fun(_curr, []), do: {:no, ~c"", []}

  defp expand_fun(curr, [cmd | t]) do
    if List.starts_with?(cmd, curr) do
      # If curr is a prefix of cmd we subtract Curr from Cmd to get the
      # characters we need to complete with.
      {:yes, Enum.reverse(Enum.reverse(cmd) -- Enum.reverse(curr)), []}
    else
      expand_fun(curr, t)
    end
  end

  defp loop(mi, opts) do
    StrFmt.to_string([
      "Search files in index ",
      {"`#{Keyword.fetch!(opts, :store)}`", :str, [:bright]},
      " (#{MergedIndex.get_num_tags(mi)} tags) with a ",
      {"command", :str, [:italic]},
      " or tags like ",
      {"angel.1937\n", :str, [:italic]},
      "cmds: q]uit, dt]upl_tags, ds]upl_size, xo|xn|ro|rn]date_old, xd|rd]bydate,\n      s]ort_tags, a]ssoc_tags, r]andom_tag, m]etrics\n",
      "> "
    ])
    |> IO.write()

    opts =
      case IO.read(:line) do
        :eof ->
          :ok

        {:error, reason} ->
          exit(reason)

        data ->
          command(mi, data |> to_string() |> String.trim(), opts)
      end
      |> tap(fn read -> read == :abort && System.halt() end)

    loop(mi, opts)
  end

  defp command(_merged_index, "", opts), do: opts

  defp command(_merged_index, "q", _opts) do
    IO.puts("CLI exits.")
    :abort
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
      File.write!(@superl_filenames, "")

      MergedIndex.files_index_from_tags(mi)
      |> Enum.each(fn {vol, files} ->
        File.write!(@superl_filenames, "\n* Volume: #{vol}:\n\n", [:append])
        dump_files(files)
      end)

      IO.puts("files names stored in #{@superl_filenames}.\n")
    end

    opts
  end

  defp command(mi, cmd, opts) when cmd in ~w(xd rd) do
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

    [MatchDate.format(result, cmd), "[CLI found #{MatchDate.size(result)} result(s)]"]
    |> IO.puts()

    opts
  end

  defp command(mi, cmd, opts) when cmd in ~w(xo xn ro rn) do
    nentries =
      Prompt.valid_default_or_new_input(
        "Confirm display first #{@num_files_search_oldness} entries (Y/new_value) ? ",
        @num_files_search_oldness,
        &Superls.string_to_numeric/1
      )

    result = MergedIndex.search_oldness(mi, cmd, nentries)

    [MatchDate.format(result, cmd), "[CLI found #{MatchDate.size(result)} result(s)]"]
    |> IO.puts()

    opts
  end

  defp command(mi, "ds", opts) do
    IO.write("group files with similar size, this may take a while ...\r")

    result =
      MergedIndex.search_similar_size(mi)

    [MatchSize.format(result), "[CLI found #{MatchSize.size(result)} result(s)]"] |> IO.puts()
    opts
  end

  defp command(mi, "dt", opts) do
    IO.write("group files with similar tags, this may take a while ...\r")

    result = MergedIndex.search_duplicated_tags(mi)

    [MatchJaro.format(result), "[CLI found #{MatchJaro.size(result)} result(s)]"] |> IO.puts()
    opts
  end

  # @limit_top_tags 500
  defp command(mi, "s", opts) do
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
          for(tag <- tags, do: [{tag, :str, [:bright]}, "  "]),
          "\n"
        ]
      end
    ]
    |> StrFmt.to_string()
    |> IO.puts()

    opts
  end

  defp command(mi, "a", opts) do
    IO.write("enter tags to associate: ")

    {result, user_tags} =
      case IO.read(:line) do
        :eof ->
          :ok

        {:error, reason} ->
          exit(reason)

        search_tags_string ->
          MergedIndex.search_bytag(mi, search_tags_string |> to_string())
      end

    user_tags_fmt =
      Enum.map(user_tags, &{&1, :str, [:bright]}) |> Enum.intersperse(" * ") |> StrFmt.to_string()

    IO.puts([
      MatchTag.format_tags(result, user_tags),
      "[CLI found #{MatchTag.size(result)} result(s) for `#{user_tags_fmt}`]"
    ])

    opts
  end

  defp command(mi, "r", opts) do
    tag = MergedIndex.random_tag(mi)
    IO.puts("Random tag: \"#{tag}\"")
    command(mi, tag, opts)
  end

  defp command(mi, user_input, opts) when byte_size(user_input) > 1 do
    {result, user_tags} = MergedIndex.search_bytag(mi, user_input)

    user_tags =
      Enum.map(user_tags, &{&1, :str, [:bright]}) |> Enum.intersperse(" * ") |> StrFmt.to_string()

    IO.puts([
      MatchTag.format_files(result),
      "[CLI found #{MatchTag.size(result)} result(s) for `#{user_tags}`]"
    ])

    opts
  end

  defp command(_merged_index, user_input, opts) do
    IO.puts("Unrecognized command: \"#{user_input}\"")
    opts
  end

  defp dump_files(files) do
    files
    |> Enum.sort(fn {fp1, _}, {fp2, _} -> String.downcase(fp1) < String.downcase(fp2) end)
    |> Enum.each(fn {fp, finfo} ->
      File.write!(
        @superl_filenames,
        StrFmt.to_string([{finfo.size, :sizeb, []}, " ", {fp, :str, []}, "\n"]),
        [:append]
      )
    end)
  end
end
