defmodule Superls.MergedIndex do
  @moduledoc """
      iex> mi = Superls.Store.get_merged_index_from_store("test", "" = _passwd)
      `[{"/media/vol1",
         %{
           "ACTION" => %{
             "filename1 ACTION" => %{
               size: 0,
               atime: 1_742_806_274,
               mtime: 1_742_806_274
             },
             "filename2 ACTION" => %{
               size: 0,
               atime: 1_742_806_274,
              mtime: 1_742_806_274
             }
           },
           "filename1" => %{
             "filename1 ACTION" => %{
              size: 0,
              atime: 1_742_806_274,
              mtime: 1_742_806_274
            }
           },
           "filename2" => %{
             "filename2 ACTION" => %{
               size: 0,
               atime: 1_742_806_274,
               mtime: 1_742_806_274
             }
           }
         }},
       {"/media/vol2 ⭐️",
         %{
           "JAZZ" => %{
             "filename3 JAZZ" => %{
               size: 0,
               atime: 1_742_806_274,
               mtime: 1_742_806_274
            }
          },
           "filename3" => %{
              "filename3 JAZZ" => %{
                size: 0,
                atime: 1_742_806_274,
                mtime: 1_742_806_274
           }
          }
        }}]`

  This sample shows a merged index from 2 volumes, `/media/vol1` and `/media/vol2 ⭐️`.

  Each index holds a map of tags.

  Last, each tag references all files that contain the tag.

  This merged index is stored encrypted or not on the local filesystem.

  """
  alias Superls.{MatchJaro, MatchSize, MatchDate, MatchTag}

  @type file_entry() :: %{size: integer(), atime: integer(), mtime: integer()}
  @type file_name() :: Path.t()
  @type relative_path() :: Path.t()
  @type tag_entry() :: %{file_name() => file_entry()}
  @type tag() :: String.t()
  @type tags() :: %{tag() => tag_entry()}
  @type volume() :: String.t()
  @opaque vol_tags() :: {volume(), tags()}
  @opaque t :: list(vol_tags())

  @spec search_duplicated_tags(t()) :: %{
          (jaro :: float()) => [{file1 :: tuple(), file2 :: tuple()}]
        }
  @doc """
  Returns a map containing best `jaro` distances as a numerical key and their associated matching files.
  """
  def search_duplicated_tags(mi) do
    files_index_from_tags(mi, false)
    |> flatten_files_vol()
    |> MatchJaro.compute()
  end

  @doc """
  Returns a sorted list of files with similar `size`.
  """
  @spec search_similar_size(t()) :: [
          {size :: integer(), list({file_name(), file_attr_tags :: map()})}
        ]
  def search_similar_size(mi) do
    files_index_from_tags(mi)
    |> flatten_files_vol()
    |> MatchSize.compute()
  end

  @doc """
  Returns a list of files sorted by the oldness `cmd` and limited in size by `nentries`.
        iex> mi |> MergedIndex.search_oldness("xo", 50)
        [..]
  """
  @spec search_oldness(t(), cmd :: String.t(), nentries :: integer()) :: [
          {file_name(), file_attr_tags :: map(), volume()}
        ]
  def search_oldness(mi, cmd, nentries) do
    files_index_from_tags(mi)
    |> flatten_files_vol()
    |> MatchDate.search_oldness(cmd, nentries)
  end

  @doc """
  Returns a list of files sorted by the oldness `cmd` from the date `date` and limited in size by `ndays`.
        iex> mi |> MergedIndex.search_bydate("xo", "10.03.31", 50)
        [..]
  """
  @spec search_bydate(t(), cmd :: String.t(), date :: Date.t(), ndays :: integer()) :: [
          {file_name(), map()}
        ]
  def search_bydate(mi, cmd, date, ndays) do
    files_index_from_tags(mi)
    |> flatten_files_vol()
    |> MatchDate.search_bydate(cmd, date, ndays)
  end

  @doc """
  Returns a list of files sorted by the oldness `cmd` from the date `date` and limited in size by `ndays`.
        iex> mi |> MergedIndex.search_bydate("xo", "10.03.31", 50)
        [..]
  """
  @spec search_bytag(t(), tags_string :: String.t()) :: term()
  def search_bytag(mi, tags_string) do
    files_index_from_tags(mi)
    |> MatchTag.compute(tags_string)
  end

  @doc """
  Returns a volume-flattened files list.
  """
  @spec flatten_files_vol(files_vol :: list({volume(), %{file_name() => map()}})) ::
          list({file_name(), map()})
  def flatten_files_vol(files_vol),
    do:
      files_vol
      |> Enum.flat_map(fn {vol, files} ->
        Enum.map(files, &:erlang.append_element(&1, vol))
      end)

  @doc """
  Count the tags
  """
  @spec get_num_tags(t()) :: count :: integer()
  def get_num_tags(mi), do: tags(mi) |> length()

  @doc """
  return the metrics as a map restricted to `limit_tags_count` most used tags.
  """
  @spec metrics(t(), limit_tags_count :: integer()) :: %{
          num_tags: integer(),
          num_files: integer(),
          files: [file_name()],
          num_tags: integer(),
          tags: [tag()],
          most_frequent: String.t()
        }

  def metrics(mi, limit_tags_count \\ 500) do
    flat_tags = tags(mi)
    files = filenames(mi)

    %{
      num_tags: length(flat_tags),
      num_files: length(files),
      files: files,
      most_frequent:
        tag_freq(mi)
        |> Enum.sort_by(fn {tag, count} -> {count, tag} end, &>/2)
        |> Enum.take(limit_tags_count)
        |> Enum.into(%{}, fn {tag, freq} ->
          case String.valid?(tag) do
            true -> {tag, freq}
            false -> {"?", freq}
          end
        end)
        |> Enum.sort(&(elem(&1, 1) >= elem(&2, 1)))
        |> Enum.map_join(", ", fn {t, num} ->
          "#{IO.ANSI.bright()}#{t}#{IO.ANSI.reset()} #{num}"
        end),
      tags: flat_tags
    }
  end

  @doc """
  Returns a random tag from a merged index.
  """
  @spec random_tag(t()) :: tag()
  def random_tag(mi), do: tags(mi) |> Enum.random()

  @doc """
  Return a map of {`tag` => `count`}.
  """
  @spec tag_freq(t()) :: %{tag() => occurence :: integer()}
  def tag_freq(mi) do
    Enum.reduce(mi, %{}, &tag_occurence(&1, &2))
  end

  @doc """
  Returns a list of files referenced by the merged index tags by volume.
  """
  @spec files_index_from_tags(t(), boolean()) :: list([{volume(), %{file_name() => map()}}])
  def files_index_from_tags(mi, prefix_tag? \\ true) when is_list(mi) do
    Enum.map(mi, fn {vol, tags} ->
      {vol,
       Enum.reduce(tags, %{}, fn {tag, files}, acc ->
         Enum.reduce(files, acc, fn {fp, fp_info}, acc2 ->
           if prefix_tag? or !fp_info.prefix_tag? do
             Map.get_and_update(acc2, fp, fn
               nil ->
                 {nil, Map.put(fp_info, :tags, [tag])}

               %{tags: tag2s} = mm ->
                 {mm, %{mm | tags: [tag | tag2s]}}
             end)
             |> elem(1)
           else
             acc2
           end
         end)
       end)}
    end)
  end

  defp tag_occurence({_vol, tags}, acc) do
    Enum.reduce(tags, acc, fn {tag, files}, acc ->
      Map.get_and_update(acc, tag, fn
        nil ->
          {nil, map_size(files)}

        num_tags ->
          {num_tags, num_tags + map_size(files)}
      end)
      |> elem(1)
    end)
  end

  #   returns the list of indexed filenames 
  @spec filenames(t()) :: list(file_name())
  defp filenames(mi) when is_list(mi) do
    mi
    |> files_index_from_tags()
    |> Enum.reduce([], fn {_vol, files}, acc ->
      acc ++ for {fp, _info} <- files, do: fp
    end)
  end

  defp tags(mi) when is_list(mi),
    do:
      Enum.reduce(mi, [], fn {_vol, tags}, acc -> acc ++ Map.keys(tags) end)
      |> Enum.uniq()
end
