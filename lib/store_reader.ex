defmodule Superls.Store.Reader do
  alias Superls.{Tag, Password}
  use Superls
  @moduledoc false

  def check_password(store, passwd) do
    case fix_password?(store, passwd) do
      false -> check_password(store, Password.io_get_passwd())
      val -> val
    end
  end

  def get_merged_index_from_store(store, passwd) do
    get_digests_names(store, passwd)
    |> load_tags(store, passwd)
    |> Tag.merge_indexes()
  end

  def load_tags(digests, store, passwd) when is_list(digests) do
    path_file = Superls.cache_store_path(store)

    Enum.reduce(digests, [], fn digest, acc ->
      vol_path = decode_digest_name(digest, passwd)
      tags = load_digest("#{path_file}/#{digest}", passwd)[:tokens]

      [{vol_path, tags} | acc]
    end)
  end

  defp fix_password?(store, passwd) do
    store_path = Superls.cache_store_path(store)

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

  def get_digests_names(store, passwd, only_passwd_check \\ false) do
    store_path = Superls.cache_store_path(store)

    case File.ls(store_path) do
      {:ok, [first | _] = list} ->
        {:ok, _} = Superls.decrypt(first, passwd)
        if only_passwd_check, do: [], else: list

      _ ->
        []
    end
  end

  def list_indexes(store, passwd) do
    store_path = Superls.cache_store_path(store)

    case File.ls(store_path) do
      {:error, :enoent} ->
        []

      {:ok, files} ->
        Enum.map(files, fn fp ->
          stat = File.stat!(Path.join([store_path, fp]), time: :posix)
          vol = Superls.decrypt(fp, passwd) |> vol_name(passwd)

          {{fp, datetime_human_str(stat.mtime), stat.size}, vol}
        end)
    end
  end

  defp vol_name({:ok, decrypted}, _),
    do: decode_index_uri(decrypted)

  defp vol_name(_, false),
    do: "** need password"

  defp vol_name(_, _),
    do: "** bad password"

  def volume_path_from_digests(store, passwd) do
    get_digests_names(store, passwd)
    |> Enum.map(fn digest -> decode_digest_name(digest, passwd) end)
  end

  def clean_old_digests(media_vol, store, passwd) do
    path_file = Superls.cache_store_path(store)

    _ =
      get_digests_names(store, passwd)
      |> Enum.map(fn digest ->
        case decode_digest_name(digest, passwd) do
          ^media_vol ->
            File.rm!("#{path_file}/#{digest}")

          _ ->
            :ok
        end
      end)

    :ok
  end

  def list_stores do
    for fname <- File.ls!(cache_path()), do: fname
  end

  def cache_path,
    do: Application.fetch_env!(:superls, :stores_path)

  defp decode_index_uri(index_uri) when is_binary(index_uri) do
    String.split(index_uri, "-")
    |> hd()
    |> Base.decode32!()
  end

  defp decode_digest_name(digest, passwd) do
    with {:ok, uri} <- Superls.decrypt(digest, passwd),
         [index22, _] <- String.split(uri, "-"),
         index_name = Path.basename(index22),
         {:ok, vol_path} <- Base.decode32(index_name) do
      vol_path
    else
      _error ->
        raise(ArgumentError, "invalid_password")
    end
  end

  defp load_digest(enc32_path, passwd) do
    [
      path: enc32_path,
      tokens:
        File.read!(enc32_path)
        |> Superls.decrypt(passwd)
        |> elem(1)
        |> :zlib.gunzip()
        |> :erlang.binary_to_term()
    ]
  end
end
