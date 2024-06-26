defmodule Superls.ApiTest do
  use ExUnit.Case

  alias Superls.{Api, Store}
  # defines default_store
  use Superls

  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  # this test uses 2 volumes_paths containing 3 files
  volumes_paths = for e <- ["vol1", "vol2"], do: Path.join(@root_dir, e)
  @volumes Enum.zip(Enum.map(volumes_paths, &Store.Writer.encode_digest_uri/1), volumes_paths)

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

  test "list indexes" do
    HelperTest.create_indexes(@volumes)
    list = Api.list_indexes(default_store())
    assert length(list) == 2
  end

  test "list indexes with password" do
    HelperTest.create_indexes(@volumes, "passwd")
    list = Api.list_indexes(default_store(), "passwd")
    assert length(list) == 2
    assert Enum.all?(list, fn {_, path} -> not String.contains?(path, "bad") end)
  end

  test "list indexes with wrong password" do
    HelperTest.create_indexes(@volumes, "passwd")
    list = Api.list_indexes(default_store(), "passwd2")

    assert length(list) == 2
    assert Enum.all?(list, fn {_, path} -> String.contains?(path, "bad") end)
  end

  test "inspect_store " do
    HelperTest.create_indexes(@volumes)
    inspect = Api.inspect_store(default_store())
    assert inspect.num_files == 5
    assert inspect.num_tags == 12
    assert length(inspect.files) == 5
    assert map_size(inspect.tags) == 12
  end

  test "inspect_store with password" do
    HelperTest.create_indexes(@volumes, "passwd")
    inspect = Api.inspect_store(default_store(), "passwd")
    assert inspect.num_files == 5
    assert inspect.num_tags == 12
    assert length(inspect.files) == 5
    assert map_size(inspect.tags) == 12
  end

  test "inspect_store with wrong password" do
    HelperTest.create_indexes(@volumes, "passwd")

    inspect =
      try do
        Api.inspect_store(default_store(), "passwd2")
      rescue
        _ -> nil
      end

    assert inspect == nil
  end

  test "search aaa from store" do
    assert HelperTest.create_indexes(@volumes) == [:ok, :ok]
    res_aaa = Api.search_from_store("aaa", default_store())
    {files, _vols} = Enum.unzip(res_aaa)
    files = for f <- files, do: f.name
    assert Enum.member?(files, @f1_bbb)
    assert Enum.member?(files, @f2_bbb)
    assert Enum.member?(files, @f3)
  end

  test "search aaa from store with password" do
    assert HelperTest.create_indexes(@volumes, "passwd") == [:ok, :ok]
    res_aaa = Api.search_from_store("aaa", default_store(), "passwd")
    {files, _vols} = Enum.unzip(res_aaa)
    files = for f <- files, do: f.name
    assert Enum.member?(files, @f1_bbb)
    assert Enum.member?(files, @f2_bbb)
    assert Enum.member?(files, @f3)
  end

  test "search bbb from store" do
    assert HelperTest.create_indexes(@volumes) == [:ok, :ok]

    res_aaa = Api.search_from_store("aaa", default_store())

    {files, _vols} = Enum.unzip(res_aaa)
    files = for f <- files, do: f.name
    assert Enum.member?(files, @f1_bbb)
    assert Enum.member?(files, @f2_bbb)
  end

  test "search eee from store" do
    assert HelperTest.create_indexes(@volumes) == [:ok, :ok]
    res_aaa = Api.search_from_store("aaa", default_store())
    {files, _vols} = Enum.unzip(res_aaa)
    files = for f <- files, do: f.name
    assert Enum.member?(files, @f3)
  end

  test "archive " do
    assert HelperTest.create_indexes(@volumes) == [:ok, :ok]
  end
end
