defmodule Superls.CLI do
  @moduledoc false
  alias Superls.{Api, SearchCLI, Store, Password}

  use Superls

  @options [
    store: :string,
    password: :boolean
  ]

  def main(argv) do
    _ = Superls.maybe_create_cache_path()

    with {opts, args, []} <-
           OptionParser.parse(argv, aliases: [p: :password, s: :store], strict: @options),
         is_password? <- Keyword.get(opts, :password, false),
         password <- if(is_password?, do: Password.io_get_passwd(), else: ""),
         store <- Keyword.get(opts, :store, default_store()),
         password <- Store.Reader.check_password(store, password) do
      main_args(args, store, password)
    else
      {_, _, wrong} ->
        IO.puts("invalid command, check #{inspect(wrong)}")
    end
  catch
    err -> IO.puts(err)
  end

  defp main_args(["archive", media_path], store_name, password) do
    Api.archive(media_path, store_name, _confirm? = true, password)
  end

  defp main_args(["search"], store_name_or_path, password) do
    store_name_or_path
    |> Store.Reader.get_merged_index_from_store(password)
    |> SearchCLI.command_line(store_name_or_path)
  rescue
    _e in File.Error ->
      default = default_store()

      store =
        case store_name_or_path do
          ^default -> ""
          any -> any
        end

      IO.puts("""
      ** store `#{store_name_or_path}` is missing.
      first create it with: superls archive /path/to/myfiles -s #{store} [- p]
      """)
  end

  defp main_args(["inspect"], store_name, passwd) do
    info = Api.inspect_store(store_name, passwd)

    vols =
      ["" | Store.Reader.volume_path_from_digests(store_name, passwd)]
      |> Enum.intersperse("\n  - ")

    IO.puts("""
    Details for store `#{store_name}`:
    most frequent tags: #{info.most_frequent}
    tags: #{info.num_tags},\nfiles: #{info.num_files},
    volumes:#{vols}
    """)
  end

  defp main_args(["help"], _store, _passwd) do
    path = Store.Reader.cache_path()

    IO.puts("""
    Usage: superls command [params] [-p -s my_store]
      -s specifies a store name other than default one `default`
      -p requires to enter a password
    Available commands are:
      archive:\n\t  superls archive /path/to/my/files\n\t  note: links prevent archiving `find /path/to/my/files -type l -ls`
      search:\n\t  superls search
      inspect:\n\t  superls inspect
    Stores:
      #{Enum.intersperse(Store.Reader.list_stores(), ", ")}

    Cache information:
      cache_path: #{path}
    """)
  end

  defp main_args([], store_name, passwd),
    do: main_args(["help"], store_name, passwd)

  defp main_args(cmd, _store, _passwd) do
    throw(
      "** unknown command `#{Enum.intersperse(cmd, " ")}`\n" <>
        "type: `superls help` for available commands"
    )
  end
end
