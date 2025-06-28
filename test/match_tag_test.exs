defmodule Superls.MatchTagTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Superls.{Store, MatchTag, MergedIndex}
  # Superls defines default_store/0
  use Superls

  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  # this test uses 2 volumes_paths containing 3 files
  volumes_paths = for e <- ["media1", "media2"], do: Path.join(@root_dir, e)
  @volumes Enum.zip(Enum.map(volumes_paths, &Store.encode_digest_uri/1), volumes_paths)

  @f1_bbb "file1.2022.FRENCH.aaa.bbb.ccc.ogv"
  @f2_bbb "file2.2022.FRENCH.AAA.bbb.ddd.ogv"
  @f3 "file3.2022.FRENCH.aaa.eee.ggg.ogv"
  @files [@f1_bbb, @f2_bbb]

  @max_files 10
  defp create_some_files do
    for {_, path} <- @volumes,
        i <- 10..@max_files,
        do: HelperTest.create_file("#{path}/home_pix", "#{@f3}.#{i}", size: i)
  end

  # create the media files to build indexes on
  setup do
    HelperTest.empty_store()
    for {_, path} <- @volumes, fi <- @files, do: HelperTest.create_file(path, fi)

    # create @f3 in one of the @volumes paths
    HelperTest.create_file(elem(hd(@volumes), 1), @f3)
    create_some_files()

    HelperTest.create_indexes(@volumes)
    :ok
  end

  test "search_matching_returns_2_volumes_whatever_result" do
    tags_string = "zQveN"

    {search_result, _tags} =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_bytag(tags_string)

    assert 2 == length(search_result)
  end

  test "search_matching_1_tag_in_fname" do
    tags_string = "file3"

    {search_result, _tags} =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_bytag(tags_string)

    assert 3 == MatchTag.size(search_result)
  end

  test "search_matching_2_tags_in_fname" do
    tags_string = "file3  eee"

    {search_result, _tags} =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_bytag(tags_string)

    assert 3 == MatchTag.size(search_result)
  end

  test "search_matching_1_tag_in_1_tag_off_fname" do
    tags_string = "file3  eef"

    {search_result, _tags} =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_bytag(tags_string)

    assert 0 == MatchTag.size(search_result)
  end

  test "search_matching_1_tag_in_path" do
    tags_string = "home_pix"

    {search_result, _tags} =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_bytag(tags_string)

    assert 2 == MatchTag.size(search_result)
  end

  test "search_matching_1_tag_in_path_1_tag_in_fname" do
    tags_string = "home_pix file3"

    {search_result, _tags} =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_bytag(tags_string)

    assert 2 == MatchTag.size(search_result)
  end

  test "pretty_print" do
    tags_string = "file3"

    {result, ""} =
      with_io(fn ->
        HelperTest.get_merged_index(default_store())
        |> MergedIndex.search_bytag(tags_string)
        |> elem(0)
        |> MatchTag.format()
      end)

    assert String.contains?("#{result}", "1 entries")
    assert String.contains?("#{result}", "2 entries")
  end
end
