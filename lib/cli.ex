defmodule Superls.CLI do
  @moduledoc false
  alias Superls.{Store, Password}

  use Superls

  @options [
    password: :boolean
  ]

  def main(argv) do
    _ = Store.maybe_create_cache_path()

    {opts, args, []} = OptionParser.parse(argv, aliases: [p: :password], strict: @options)
    main_args(args, opts)
  end

  defp main_args(["index" | args], opts) do
    with {:ok, vol_path, store_name} <- parse_index_args(args),
         true <- index_path?(vol_path, File.dir?(vol_path)) do
      is_password? = Keyword.get(opts, :password, false)
      password = if(is_password?, do: Password.io_get(), else: "")

      Store.archive(vol_path, store_name, password)
    end
  end

  defp main_args(["help"], _passwd) do
    path = Store.cache_path()

    IO.puts("""
    Usage:

      superls [myindex]
        search for tags in index `myindex` (default index: `default`) 

      superls index /path/to/my/volume/files [index_name] [-p]
            build the index index_name and save it locally on disk
            -p requires to enter a password to encrypt the saved index
            Note: links prevent indexing, execute this before indexing: `find /path/to/my/files -type l -ls`

    Currently saved indexes:
      #{Enum.intersperse(Store.list_stores(), ", ")}
      in #{path}
    """)
  end

  # search in store
  defp main_args(args, passwd) do
    passwd = normalize_passwd(passwd)
    store_name = valid_name(args)

    try do
      mi = Store.get_merged_index_from_store(store_name, passwd)
      :ok = start_interactive([mi, [store: store_name, passwd: passwd]])
    rescue
      _e in File.Error ->
        default_store = default_store()

        store =
          case store_name do
            ^default_store -> ""
            any -> any
          end

        IO.puts("""
        ** index `#{store_name}` is missing.
        first create index with: superls index /path/to/my/volume_files -i #{store} [- p]
        """)

        {:error, :store_missing}
    catch
      :enoent ->
        IO.puts("** index `#{store_name}` not found\n\ntry: superls help")
        {:error, :enoent}

      err ->
        IO.puts("#{err}")
        retry_with_password(args)
    end
  end

  defp parse_index_args([vol_path, store]), do: {:ok, vol_path, store}
  defp parse_index_args([vol_path]), do: {:ok, vol_path, default_store()}

  defp parse_index_args(_volume_path_notfound) do
    IO.puts("** error: missing volume path\n\ntry: superls help")
    {:error, :volume_path_notfound}
  end

  defp index_path?(_, true), do: true

  defp index_path?(vol_path, false) do
    IO.puts("** error: `#{vol_path}` is an invalid directory\n\ntry: superls help")
    {:error, :invalid_directory}
  end

  if Mix.env() == :test do
    defp retry_with_password(args) do
      main_args(args, "secret")
    end

    defp start_interactive(_args), do: :ok
  else
    defp retry_with_password(args) do
      main_args(args, Password.io_get())
    end

    defp start_interactive(args) do
      :ok = :shell.start_interactive({Superls.CLI.Search, :start, args})
      :timer.sleep(:infinity)
    end
  end

  defp normalize_passwd(passwd) when is_list(passwd), do: ""
  defp normalize_passwd(passwd), do: passwd

  defp valid_name([]), do: default_store()
  defp valid_name([str | _]), do: str
end
