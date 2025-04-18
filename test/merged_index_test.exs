defmodule Superls.ApiTest do
  use ExUnit.Case

  alias Superls.{Store, Tag, MergedIndex}
  # defines default_store
  use Superls

  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  # this test uses 2 volumes_paths containing 3 files
  volumes_paths = for e <- ["vol1", "vol2"], do: Path.join(@root_dir, e)
  @volumes Enum.zip(Enum.map(volumes_paths, &Store.encode_digest_uri/1), volumes_paths)

  @f1_bbb "file1.2022.FRENCH.aaa.bbb.ccc.ogv"
  @f2_bbb "file2.2022.FRENCH.AAA.bbb.ddd.ogv"
  @f3 "file3.2022.FRENCH.aaa.eee.ggg.ogv"
  @files [@f1_bbb, @f2_bbb]

  # create the media files to build indexes on
  setup do
    HelperTest.empty_store()

    for {_, path} <- @volumes, fi <- @files, do: HelperTest.create_file(path, fi)

    # create @f3 in one of the @volumes paths
    HelperTest.create_file(elem(hd(@volumes), 1), @f3)

    :ok
  end

  test "list indexes without password" do
    HelperTest.create_indexes(@volumes)
    list = Store.list_indexes(default_store())
    assert length(list) == 2
  end

  test "list indexes with password" do
    HelperTest.create_indexes(@volumes, "passwd")
    list = Store.list_indexes(default_store(), "passwd")
    assert length(list) == 2
    assert Enum.all?(list, fn {_, path} -> not String.contains?(path, "bad") end)
  end

  test "list indexes with wrong password" do
    HelperTest.create_indexes(@volumes, "passwd")
    list = Store.list_indexes(default_store(), "passwd2")

    assert length(list) == 2
    assert Enum.all?(list, fn {_, path} -> String.contains?(path, "bad") end)
  end

  test "inspect_store without password" do
    HelperTest.create_indexes(@volumes)
    mi = HelperTest.get_merged_index(default_store())

    result = MergedIndex.metrics(mi)
    assert result.num_files == 5
    assert result.num_tags == 12
    assert length(result.files) == 5
    assert length(result.tags) == 12
  end

  test "inspect_store with password" do
    HelperTest.create_indexes(@volumes, "passwd")
    mi = HelperTest.get_merged_index(default_store(), "passwd")

    result = MergedIndex.metrics(mi)
    assert result.num_files == 5
    assert result.num_tags == 12
    assert length(result.files) == 5
    assert length(result.tags) == 12
  end

  test "inspect_store with wrong password" do
    HelperTest.create_indexes(@volumes, "passwd")

    result =
      try do
        HelperTest.get_merged_index(default_store(), "passwd2")
        |> MergedIndex.metrics()
      rescue
        _ -> nil
      end

    assert result == nil
  end

  test "search aaa from store" do
    HelperTest.create_indexes(@volumes)
    # search_res = Api.search_from_store("aaa", default_store())
    search_res =
      HelperTest.get_merged_index(default_store()) |> Tag.search_matching_tags("aaa") |> elem(0)

    files = HelperTest.extract_filenames_from_search(search_res)
    assert Enum.member?(files, @f1_bbb)
    assert Enum.member?(files, @f2_bbb)
    assert Enum.member?(files, @f3)
  end

  test "search aaa from store with password" do
    HelperTest.create_indexes(@volumes, "passwd")

    search_res =
      HelperTest.get_merged_index(default_store(), "passwd")
      |> Tag.search_matching_tags("aaa")
      |> elem(0)

    # search_res = Api.search_from_store("aaa", default_store(), "passwd")
    files = HelperTest.extract_filenames_from_search(search_res)

    assert Enum.member?(files, @f1_bbb)
    assert Enum.member?(files, @f2_bbb)
    assert Enum.member?(files, @f3)
  end

  test "search bbb from store" do
    HelperTest.create_indexes(@volumes)

    search_res =
      HelperTest.get_merged_index(default_store())
      |> Tag.search_matching_tags("bbb")
      |> elem(0)

    # search_res = Api.search_from_store("aaa", default_store())
    files = HelperTest.extract_filenames_from_search(search_res)

    assert Enum.member?(files, @f1_bbb)
    assert Enum.member?(files, @f2_bbb)
  end

  test "search eee from store" do
    HelperTest.create_indexes(@volumes)

    search_res =
      HelperTest.get_merged_index(default_store()) |> Tag.search_matching_tags("aaa") |> elem(0)

    # search_res = Api.search_from_store("aaa", default_store())
    files = HelperTest.extract_filenames_from_search(search_res)
    assert Enum.member?(files, @f3)
  end

  test "archive " do
    assert HelperTest.create_indexes(@volumes) == :ok
  end
end
