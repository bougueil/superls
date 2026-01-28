defmodule Superls.Store do
  alias Superls.{Prompt, Tag, MergedIndex, Password}
  use Superls
  @moduledoc "Store access facilities."
  @sep_path "-"

  @doc "Create a `merged_index` from `media_dir`, `store` and `passwd`."
  @spec archive(media_dir :: MergedIndex.volume(), store :: store(), passwd :: String.t()) ::
          no_return()
  def archive(media_dir, store_name \\ default_store(), passwd \\ "") do
    !File.dir?(media_dir) &&
      Superls.halt("error: media_dir: #{media_dir} must point to a directory")

    if Prompt.valid_default_yes?("Update index `#{store_name}` ?") do
      store_cache_path = maybe_create_dir(store_name)
      media_dir = String.trim_trailing(media_dir, "/")

      digest =
        Tag.index_media_dir(media_dir)
        |> :erlang.term_to_binary([:compressed])
        |> Superls.encrypt(passwd)

      try do
        clean_old_digests(media_dir, store_name, passwd)

        encoded_path =
          "#{store_cache_path}/#{Superls.encrypt(encode_digest_uri(media_dir), passwd)}"

        :ok = File.write(encoded_path, digest)
        Superls.puts("\rindex `#{store_name}` updated.")
      rescue
        e in ArgumentError ->
          Superls.halt(
            "** invalid password: '#{passwd}' for store '#{store_name}'.\nerror: #{inspect(e)}"
          )
      end
    else
      Superls.halt("Aborting.")
    end
  end

  @doc "Returns the `digest` from a `vol_path`"
  @spec encode_digest_uri(vol_path :: MergedIndex.volume()) :: digest :: String.t()
  def encode_digest_uri(vol_path) when is_binary(vol_path),
    do: "#{Base.encode32(vol_path)}#{@sep_path}#{Path.basename(vol_path)}"

  @doc "Returns the `store` cache `path`"
  @spec cache_store_path(store()) :: path :: Path.t()
  def cache_store_path(store),
    do: Path.expand("#{store}", cache_path())

  @spec maybe_create_cache_path() :: Path.t()
  def maybe_create_cache_path,
    do: maybe_create_dir("")

  @doc "Maybe creates and returns the `store` cache `path`"
  @spec maybe_create_dir(store()) :: store_path :: Path.t()
  def maybe_create_dir(store) do
    store_path = cache_store_path(store)
    do_maybe_create_dir(File.exists?(store_path), store, store_path)
  end

  @doc "the cache `path`"
  @spec cache_path() :: path :: Path.t()
  def cache_path,
    do: Application.fetch_env!(:superls, :stores_path)

  @doc "verify `passwd`."
  @spec check_password(store(), passwd :: String.t()) :: passwd :: String.t()
  def check_password(store, passwd) do
    case fix_password?(store, passwd) do
      false -> check_password(store, Password.io_get())
      val -> val
    end
  end

  @doc """
    get the `merged_index` from `store` and `passwd` or returns an error: 
    {:error, :enoent} a digest cannot be found
    {:error, :invalid_passwd} the password is invalid
  """
  @spec get_merged_index_from_store(store :: store(), passwd :: String.t()) ::
          merged_index :: MergedIndex.t() | {:error, :enoent} | {:error, :invalid_passwd}

  def get_merged_index_from_store(store, passwd \\ "") do
    path_file = cache_store_path(store)

    list_indexes(store, passwd)
    |> Task.async_stream(
      fn
        {{_digest, _date, _sz}, "** bad password" = vol_path} ->
          {vol_path, %{error: "invalid_passwd"}}

        {{digest, _date, _sz}, vol_path} ->
          {vol_path, load_digest("#{path_file}/#{digest}", passwd)[:tokens]}
      end,
      ordered: false
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  @doc "Get the `indexes` list from `store` and `password`."
  @spec list_indexes(store :: store(), password :: String.t()) :: indexes :: [tuple()]
  def list_indexes(store \\ default_store(), passwd \\ "") do
    store_path = cache_store_path(store)

    case File.ls(store_path) do
      {:error, :enoent} ->
        []

      {:ok, files} ->
        Enum.map(files, fn fp ->
          stat = File.stat!(Path.join([store_path, fp]), time: :posix)
          vol = Superls.decrypt(fp, passwd) |> vol_name(passwd)
          {{fp, stat.mtime, stat.size}, vol}
        end)
    end
  end

  @doc "Get the `volume_path` list from `store` and `password`."
  @spec volume_path_from_digests(String.t(), String.t()) ::
          volume_path :: [{Path.t(), String.t()}]
  def volume_path_from_digests(store, passwd),
    do:
      list_indexes(store, passwd)
      |> Enum.map(fn {{fp, _, _}, vol} -> {vol, fp} end)

  @doc "Get the `stores` list."
  @spec list_stores() :: stores :: [Path.t()]
  def list_stores, do: File.ls!(cache_path())

  defp do_maybe_create_dir(true, _store, store_path),
    do: store_path

  defp do_maybe_create_dir(false, store, store_path) do
    Prompt.valid_default_no?("Confirm create a new store `#{store}`") &&
      Superls.halt("User aborts.")

    :ok = File.mkdir_p!(store_path)
    store_path
  end

  defp clean_old_digests(media_vol, store, passwd) do
    path_file = cache_store_path(store)

    list_indexes(store, passwd)
    |> Enum.each(fn {{fp, _, _}, vol} ->
      if vol == media_vol do
        File.rm!("#{path_file}/#{fp}")
      end
    end)
  end

  defp fix_password?(store, passwd) do
    store_path = cache_store_path(store)

    case File.ls(store_path) do
      {:ok, [first | _]} ->
        {:ok, decrypted} = Superls.decrypt(first, passwd)

        case decrypted do
          # XCP wiil always be a valid keyword ?
          "XCP" <> _ -> false
          _ -> passwd
        end

      _ ->
        passwd
    end
  rescue
    _err ->
      false
  end

  defp vol_name({:ok, clear}, _), do: decode_index_uri(clear)
  defp vol_name(_, ""), do: "** need password"
  defp vol_name(_, _), do: "** bad password"

  defp decode_index_uri(index_uri) when is_binary(index_uri) do
    with [encr_path, _] <- String.split(index_uri, "-", parts: 2),
         {:ok, path} <- Base.decode32(encr_path) do
      path
    else
      _ -> "** bad password"
    end
  end

  def load_digest(enc32_path, passwd) do
    with {:ok, data} <- File.read(enc32_path),
         {:ok, data} <- Superls.decrypt(data, passwd),
         tokens <- :erlang.binary_to_term(data) do
      [
        path: enc32_path,
        tokens: tokens
      ]
    else
      {:error, :invalid} -> %{error: "invalid_passwd"}
      {:error, :enoent} -> %{error: "index file not found"}
    end
  end
end
