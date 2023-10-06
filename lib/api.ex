defmodule Superls.Api do
  @moduledoc """
  `Superls` API for the CLI.
  """
  alias Superls.{Store, Tag, MatchJaro, MatchSize, MatchDate}

  use Superls

  @doc """
  """
  def list_indexes(store_name \\ default_store()) do
    for f <- Store.list_indexes(store_name) do
      try do
        {f, Store.decode_index_uri(elem(f, 0))}
      rescue
        _ -> []
      end
    end
  end

  @doc """
  """
  def inspect_store(store_name \\ default_store()) do
    Store.inspect_store(store_name)
  end

  @doc """
  """

  def search_from_store(criteria_str, store_name_or_path \\ default_store())
      when is_binary(store_name_or_path) do
    merged_index = Store.get_indexes_from_resource(store_name_or_path)
    # dbg(merged_index)
    search_from_index(criteria_str, merged_index)
  end

  def search_from_index(criteria_str, merged_index) when is_map(merged_index) do
    Tag.search_matching_tags(merged_index, criteria_str)
  end

  @doc """
  """
  def archive(media_path, store_name \\ default_store(), confirm? \\ false) do
    Store.archive(media_path, store_name, confirm?)
  end

  def search_duplicated_tags(store_name_or_path) when is_binary(store_name_or_path) do
    Store.get_indexes_from_resource(store_name_or_path)
    |> search_duplicated_tags()
  end

  def search_duplicated_tags(merged_index) do
    Tag.files_index_from_tags(merged_index)
    |> MatchJaro.best_jaro()
  end

  def search_similar_size(store_name_or_path) when is_binary(store_name_or_path) do
    Store.get_indexes_from_resource(store_name_or_path)
    |> search_similar_size()
  end

  def search_similar_size(merged_index) do
    Tag.files_index_from_tags(merged_index)
    |> MatchSize.best_size()
  end

  def search_oldness(store_name_or_path, cmd, nentries) when is_binary(store_name_or_path) do
    Store.get_indexes_from_resource(store_name_or_path)
    |> search_oldness(cmd, nentries)
  end

  def search_oldness(merged_index, cmd, nentries) do
    Tag.files_index_from_tags(merged_index)
    |> MatchDate.search_oldness(cmd, nentries)
  end

  def search_bydate(store_name_or_path, cmd, date, ndays) when is_binary(store_name_or_path) do
    Store.get_indexes_from_resource(store_name_or_path)
    |> search_bydate(cmd, date, ndays)
  end

  def search_bydate(merged_index, cmd, date, ndays) do
    Tag.files_index_from_tags(merged_index)
    |> MatchDate.search_bydate(cmd, date, ndays)
  end
end
