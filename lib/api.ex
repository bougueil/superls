defmodule Superls.Api do
  @moduledoc """
  `Superls` API for the CLI.
  """
  alias Superls.{Store, Tag}

  use Superls

  @doc """
  return the list of indexes for a store
  """
  def list_indexes(store_name \\ default_store(), passwd \\ false) do
    Store.Reader.list_indexes(store_name, passwd)
  end

  @doc """
  return the store main metrics in a map
  """
  def inspect_store(store_name \\ default_store(), password \\ false) do
    tags = Store.Reader.get_merged_index_from_store(store_name, password)
    files = Tag.files_index_from_tags(tags)

    %{
      num_tags: map_size(tags),
      num_files: length(files),
      files: files,
      most_frequent_100:
        Tag.tag_freq(tags)
        |> Enum.take(100)
        |> Enum.into(%{}, fn {tag, {freq, _}} -> {tag, freq} end),
      tags: tags
    }
  end

  @doc """
  """

  def search_from_store(criteria_str, store_name_or_path \\ default_store(), password \\ false)
      when is_binary(store_name_or_path) do
    merged_index = Superls.Store.Reader.get_merged_index_from_store(store_name_or_path, password)
    Tag.search_matching_tags(merged_index, criteria_str)
  end

  @doc """
  """
  def archive(media_path, store_name \\ default_store(), confirm? \\ false, passwd \\ false) do
    # make sure we can read the store with this password
    _ = Store.Reader.get_digests_names(store_name, passwd, _only_passwd_check = true)

    Store.Writer.archive(media_path, store_name, passwd, confirm?)
  end

  def search_duplicated_tags(store_name_or_path, password \\ false)
      when is_binary(store_name_or_path) do
    Store.Reader.get_merged_index_from_store(store_name_or_path, password)
    |> Tag.search_duplicated_tags()
  end

  def search_similar_size(store_name_or_path, password \\ false)
      when is_binary(store_name_or_path) do
    Store.Reader.get_merged_index_from_store(store_name_or_path, password)
    |> Tag.search_similar_size()
  end

  def search_oldness(store_name_or_path, cmd, nentries, password \\ false)
      when is_binary(store_name_or_path) do
    Store.Reader.get_merged_index_from_store(store_name_or_path, password)
    |> Tag.search_oldness(cmd, nentries)
  end

  def search_bydate(store_name_or_path, cmd, date, ndays, password \\ false)
      when is_binary(store_name_or_path) do
    Store.Reader.get_merged_index_from_store(store_name_or_path, password)
    |> Tag.search_bydate(cmd, date, ndays)
  end
end
