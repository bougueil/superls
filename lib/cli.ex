defmodule Superls.CLI do
  @moduledoc false
  alias Superls.{Api, Store, Tag, MatchJaro, MatchSize}

  use Superls

  # escript main entry point 
  def main(cmd) do
    case cmd do
      [] ->
        help()

      ["help" | _args] ->
        help()

      ["list_indexes" | args] ->
        list_indexes(args)

      ["inspect" | args] ->
        my_inspect(args)

      ["search" | args] ->
        search(args)

      ["archive", media_path | args] ->
        archive(media_path, args)

      _ ->
        IO.puts("wrong command: #{Enum.map_join(cmd, " ", & &1)}")
        help()
    end
  end

  defp my_inspect([]), do: my_inspect([default_store()])

  defp my_inspect([store_name]) do
    info = Api.inspect_store(store_name)

    IO.puts(
      "tags: #{info.num_tags},\nfiles:  #{info.num_files},\n100 most frequent tags : #{inspect(info.most_frequent_100, pretty: true)}"
    )
  end

  defp list_indexes([]), do: list_indexes([default_store()])

  defp list_indexes([store_name]) do
    Api.list_indexes(store_name)
    |> pp_indexes()
    |> IO.puts()
  end

  defp archive(media_path, []),
    do: archive(media_path, [default_store()])

  defp archive(media_path, [store_name]),
    do: Api.archive(media_path, store_name, _confirm? = true)

  defp search([]), do: search([default_store()])

  defp search([store_name_or_path]) do
    store_name_or_path
    |> Store.get_indexes_from_resource()
    |> human_search(store_name_or_path)
  end

  defp human_search(merged_index, store_name_or_path) do
    IO.write("""
      #{map_size(merged_index)} tags in '#{store_name_or_path}' - enter any string like `1967 twice`, q]uit or
      s]ort_tags, `dt]upl_tags, ds]upl_size.
    """)

    user_tags = IO.gets("-? ") |> String.trim_trailing()

    case user_tags do
      "" ->
        human_search(merged_index, store_name_or_path)

      "q" ->
        IO.puts("CLI exits.")

      "s" ->
        res = Tag.tag_freq(merged_index)

        IO.puts(
          "[{tag, {num_occur, from_same_host?}}, ..]\n#{inspect(res, pretty: true, limit: :infinity)}"
        )

        human_search(merged_index, store_name_or_path)

      "dt" ->
        merged_index
        |> Api.search_duplicated_tags()
        |> MatchJaro.pretty_print_result()

        human_search(merged_index, store_name_or_path)

      "ds" ->
        merged_index
        |> Api.search_similar_size()
        |> MatchSize.pretty_print_result()

        human_search(merged_index, store_name_or_path)

      # USER entered tags e.g. `1916 world wars`
      user_input ->
        res =
          Api.search_from_index(user_input, merged_index)
          |> search_output_friendly()

        IO.puts(
          "CLI found \r#{length(res)} result(s) for \"#{String.trim(user_input, "\n")}\" ------------------"
        )

        human_search(merged_index, store_name_or_path)
    end
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

  defp help() do
    path = Store.cache_path()
    indexes = Enum.map(Store.list_stores(), &{&1, Api.list_indexes(&1)})
    # dbg(indexes)

    IO.puts("""
    Usage: superls command {params}
    Available commands are:
      archive:\n\t  superls archive /path/to/my/files\n\t  (bad links prevent archiving can be detected with: find . -type l -ls)
      search:\n\t  superls search [store | path]
      list_indexes:\n\t  superls list_indexes [store]
      inspect:\n\t  superls inspect [store]
    Cache information:
      cache_path: #{path}
      stores: #{Enum.intersperse(Store.list_stores(), ", ")}
      media volumes by store:\n#{expand_stores(indexes)}
    """)
  end

  defp pp_indexes(indexes),
    do:
      Enum.map_join(indexes, "\n", fn {{index, last_updated, size}, path} ->
        "\t  #{last_updated} #{path} (#{Superls.pp_sz(size)}) #{index}"
      end)

  defp expand_stores(indexes),
    do:
      Enum.map_join(indexes, "\n", fn {store, indexes} ->
        "\t  #{store}:\n#{pp_indexes(indexes)}"
      end)
end
