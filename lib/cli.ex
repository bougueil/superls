defmodule Superls.CLI do
  @moduledoc false
  alias Superls.{Api, Store, SearchCLI}

  use Superls

  # escript main entry point 
  def main(cmd) do
    Store.maybe_create_cache_path()

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
    |> SearchCLI.command_line(store_name_or_path)
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
