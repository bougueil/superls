defmodule StrFmtTest do
  use ExUnit.Case, async: true
  alias Superls.StrFmt

  # ncols string
  @max_str "aaaaaaaaaabbbbbbbbbbccccccccccdddddddddd"

  test ":sizeb B" do
    {res, len} = [{1024, :sizeb, []}] |> StrFmt.ansi_assemble()
    assert res == "  1024B"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":sizeb K" do
    {res, len} = [{1_048_576, :sizeb, []}] |> StrFmt.ansi_assemble()
    assert res == "1024.0K"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":sizeb M" do
    {res, len} = [{1_073_741_824, :sizeb, []}] |> StrFmt.ansi_assemble()
    assert res == "1024.0M"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":sizeb G" do
    {res, len} = [{1_099_511_627_776, :sizeb, []}] |> StrFmt.ansi_assemble()
    assert res == "1024.0G"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":date" do
    {res, len} = [{1_696_153_262, :date, []}] |> StrFmt.ansi_assemble()

    assert res == "2023-10-01"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":datetime" do
    {res, len} = [{1_696_153_262, :datetime, []}] |> StrFmt.ansi_assemble()

    assert res == "23-10-01 09:41:02"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":scr, string len = ncols" do
    {res, len} = [{@max_str, :scr, []}] |> StrFmt.ansi_assemble()

    assert res == @max_str
    assert HelperTest.fit_in_ncols?(len)
  end

  test "no newline, overflow" do
    {res, len} = [{@max_str, :str, []}, {@max_str, :scr, []}] |> StrFmt.ansi_assemble()

    assert res == @max_str
    assert HelperTest.fit_in_ncols?(len)
  end

  test "newline" do
    {res, len} = [{@max_str, :str, []}, "\n", {@max_str, :scr, []}] |> StrFmt.ansi_assemble()

    assert res == @max_str <> "\n" <> @max_str
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":scr, string len = ncols - 1" do
    str = String.slice(@max_str, 0..38)

    {res, len} =
      [{str, :scr, []}]
      |> StrFmt.ansi_assemble()

    assert res == str
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":scr, string len = ncols + 2" do
    str = "A" <> @max_str <> "B"

    {res, len} =
      [{str, :scr, []}]
      |> StrFmt.ansi_assemble()

    assert res == "Aaaaaaaaaaabbbbbbbb..ccccccccddddddddddB"
    assert HelperTest.fit_in_ncols?(len)
  end

  test "{:scr, 50} with string len > ncols" do
    str = "A" <> @max_str <> "B"

    {res, len} =
      [{str, {:scr, 50}, []}]
      |> StrFmt.ansi_assemble()

    assert res == "Aaaaaaaaa..ddddddddB"
    assert HelperTest.fit_in_ncols?(len)
  end

  test "5 x {:scr, 20} with string len = ncols" do
    {res, len} =
      [
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []}
      ]
      |> StrFmt.ansi_assemble()

    assert res == "aaa..dddaaa..dddaaa..dddaaa..dddaaa..ddd"
    assert HelperTest.fit_in_ncols?(len)
  end

  test "overflow 2 x {:scr, 60} with string len = ncols" do
    {res, len} =
      [
        {@max_str, {:scr, 60}, []},
        "  ",
        {@max_str, {:scr, 60}, []}
      ]
      |> StrFmt.ansi_assemble()

    assert res == "aaaaaaaaaab..cdddddddddd  aaaaaa..dddddd"
    assert HelperTest.fit_in_ncols?(len)
  end

  test "overflow multiline {:scr, 60}  + :scr + {:scr, 60}  + :scr" do
    {res, len} =
      [
        {@max_str, {:scr, 60}, []},
        "  ",
        {@max_str, :scr, []},
        "\n",
        {@max_str, {:scr, 60}, []},
        "  ",
        {@max_str, :scr, []}
      ]
      |> StrFmt.ansi_assemble()

    assert res ==
             "aaaaaaaaaab..cdddddddddd  aaaaaa..dddddd\naaaaaaaaaab..cdddddddddd  aaaaaa..dddddd"

    assert HelperTest.fit_in_ncols?(len)
  end

  test "multiple str_fmt" do
    {res, len} = ["\n", {"Bla", :str, []}, "\n"] |> StrFmt.ansi_assemble()

    assert res == "\nBla\n"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":padr" do
    str = "Tag _"

    {res, len} = [{str, :padr, []}] |> StrFmt.ansi_assemble()
    assert res == "Tag ____________________________________"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":padl" do
    str = "_ Tag"

    {res, len} = [{str, :padl, []}] |> StrFmt.ansi_assemble()

    assert res == "____________________________________ Tag"
    assert HelperTest.fit_in_ncols?(len)
  end

  test "invalid str_fmt_unit" do
    {res, len} = [{"Bla", :foo, []}] |> StrFmt.ansi_assemble()
    assert res == "invalid str_fmt type: `:foo`"
    assert HelperTest.fit_in_ncols?(len)
  end

  if IO.ANSI.enabled?() do
    test ":sizeb + color" do
      {res, len} =
        [{1024, :sizeb, [:light_blue_background]}]
        |> StrFmt.ansi_assemble()

      assert res == "\e[104m  1024B\e[0m"
      assert HelperTest.fit_in_ncols?(len)
    end

    test ":str + color" do
      {res, len} =
        [{"Example", :str, [:blue_background]}]
        |> StrFmt.ansi_assemble()

      assert res == "\e[44mExample\e[0m"
      assert HelperTest.fit_in_ncols?(len)
    end
  end

  test ":date + color" do
    {res, len} = [{1_696_153_262, :date, [:blue]}] |> StrFmt.ansi_assemble()
    assert res == "\e[34m2023-10-01\e[0m"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":scr, string len = ncols + color" do
    str = @max_str

    {res, len} = [{str, :scr, [:blue]}] |> StrFmt.ansi_assemble()
    assert res == "\e[34maaaaaaaaaabbbbbbbbbbccccccccccdddddddddd\e[0m"
    assert HelperTest.fit_in_ncols?(len)
  end

  test ":scr, string len = ncols + 2 + color" do
    str = "A" <> @max_str <> "B"

    {res, len} = [{str, :scr, [:blue]}] |> StrFmt.ansi_assemble()
    assert res == "\e[34mAaaaaaaaaaabbbbbbbb..ccccccccddddddddddB\e[0m"
    assert HelperTest.fit_in_ncols?(len)
  end

  test "one :str + one newline" do
    {res, len} = ["\n", {"Bla", :str, [:blue]}, "\n"] |> StrFmt.ansi_assemble()

    assert res == "\n\e[34mBla\e[0m\n"
    assert HelperTest.fit_in_ncols?(len)
  end

  @ncols StrFmt.ncols()

  test "1 newline + 1 :str + 1 :str" do
    bla = String.pad_leading("", div(@ncols, 2))
    {res, len} = ["\n", {bla, :str, [:red]}, {bla, :str, [:cyan]}] |> StrFmt.ansi_assemble()

    assert res == "\n\e[31m" <> bla <> "\e[0m\e[36m" <> bla <> "\e[0m"
    assert HelperTest.fit_in_ncols?(len)
  end
end
