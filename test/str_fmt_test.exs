defmodule StrFmtTest do
  use ExUnit.Case, async: true
  require Logger
  alias Superls.StrFmt

  # ncols string
  @max_str "aaaaaaaaaabbbbbbbbbbccccccccccdddddddddd"

  test ":sizeb B" do
    res = [{1024, :sizeb, []}] |> StrFmt.to_string()

    assert res == "  1024B"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":sizeb K" do
    res = [{1_048_576, :sizeb, []}] |> StrFmt.to_string()
    assert res == "1024.0K"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":sizeb M" do
    res = [{1_073_741_824, :sizeb, []}] |> StrFmt.to_string()
    assert res == "1024.0M"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":sizeb G" do
    res = [{1_099_511_627_776, :sizeb, []}] |> StrFmt.to_string()
    assert res == "1024.0G"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":date" do
    res =
      [{1_696_153_262, :date, []}]
      |> StrFmt.to_string()

    assert res == "2023-10-01"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":datetime" do
    res =
      [{1_696_153_262, :datetime, []}]
      |> StrFmt.to_string()

    assert res == "23-10-01 09:41:02"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":scr, string len = ncols" do
    res =
      [{@max_str, :scr, []}]
      |> StrFmt.to_string()

    assert res == @max_str
    assert HelperTest.fit_in_ncols?(res)
  end

  test "no newline, overflow" do
    res =
      [{@max_str, :str, []}, {@max_str, :scr, []}]
      |> StrFmt.to_string()

    assert res == @max_str
    assert HelperTest.fit_in_ncols?(res)
  end

  test "newline" do
    res =
      [{@max_str, :str, []}, "\n", {@max_str, :scr, []}]
      |> StrFmt.to_string()

    assert res == @max_str <> "\n" <> @max_str
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":scr, string len = ncols - 1" do
    str = String.slice(@max_str, 0..38)

    res =
      [{str, :scr, []}]
      |> StrFmt.to_string()

    assert res == str
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":scr, string len = ncols + 2" do
    str = "A" <> @max_str <> "B"

    res =
      [{str, :scr, []}]
      |> StrFmt.to_string()

    assert res == "Aaaaaaaaaaabbbbbbbb..ccccccccddddddddddB"
    assert HelperTest.fit_in_ncols?(res)
  end

  test "{:scr, 50} with string len > ncols" do
    str = "A" <> @max_str <> "B"

    res =
      [{str, {:scr, 50}, []}]
      |> StrFmt.to_string()

    assert res == "Aaaaaaaaa..ddddddddB"
    assert HelperTest.fit_in_ncols?(res)
  end

  test "5 x {:scr, 20} with string len = ncols" do
    res =
      [
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []},
        {@max_str, {:scr, 20}, []}
      ]
      |> StrFmt.to_string()

    assert res == "aaa..dddaaa..dddaaa..dddaaa..dddaaa..ddd"
    assert HelperTest.fit_in_ncols?(res)
  end

  test "overflow 2 x {:scr, 60} with string len = ncols" do
    res =
      [
        {@max_str, {:scr, 60}, []},
        "  ",
        {@max_str, {:scr, 60}, []}
      ]
      |> StrFmt.to_string()

    assert res == "aaaaaaaaaab..cdddddddddd  aaaaaa..dddddd"
    assert HelperTest.fit_in_ncols?(res)
  end

  test "overflow multiline {:scr, 60}  + :scr + {:scr, 60}  + :scr" do
    res =
      [
        {@max_str, {:scr, 60}, []},
        "  ",
        {@max_str, :scr, []},
        "\n",
        {@max_str, {:scr, 60}, []},
        "  ",
        {@max_str, :scr, []}
      ]
      |> StrFmt.to_string()

    assert res ==
             "aaaaaaaaaab..cdddddddddd  aaaaaa..dddddd\naaaaaaaaaab..cdddddddddd  aaaaaa..dddddd"

    assert HelperTest.fit_in_ncols?(res)
  end

  test "multiple str_fmt" do
    res = ["\n", {"Bla", :str, []}, "\n"] |> StrFmt.to_string()

    assert res == "\nBla\n"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":padr" do
    str = "Tag _"

    res = [{str, :padr, []}] |> StrFmt.to_string()
    assert res == "Tag ____________________________________"
    assert HelperTest.fit_in_ncols?(res)
  end

  test ":padl" do
    str = "_ Tag"

    res =
      [{str, :padl, []}]
      |> StrFmt.to_string()

    assert res == "____________________________________ Tag"
    assert HelperTest.fit_in_ncols?(res)
  end

  test "invalid str_fmt_spec" do
    res = [{"Bla", :foo, [:blue]}] |> StrFmt.to_string()
    assert res == "invalid str_fmt type: `:foo`"
    assert HelperTest.fit_in_ncols?(res)
  end

  if IO.ANSI.enabled?() do
    test ":sizeb + color" do
      res =
        [{1024, :sizeb, [:light_blue_background]}]
        |> StrFmt.to_string()

      assert res == "\e[104m  1024B\e[0m"
      assert HelperTest.fit_in_ncols?(res)
    end

    test ":str + color" do
      res =
        [{"Example", :str, [:blue_background]}]
        |> StrFmt.to_string()

      assert res == "\e[44mExample\e[0m"
      assert HelperTest.fit_in_ncols?(res)
    end

    test ":date + color" do
      res = [{1_696_153_262, :date, [:blue]}] |> StrFmt.to_string()
      assert res == "\e[34m2023-10-01\e[0m"
      assert HelperTest.fit_in_ncols?(res)
    end

    test ":scr, string len = ncols + color" do
      str = @max_str

      res = [{str, :scr, [:blue]}] |> StrFmt.to_string()
      assert res == "\e[34maaaaaaaaaabbbbbbbbbbccccccccccdddddddddd\e[0m"
      assert HelperTest.fit_in_ncols?(res)
    end

    test ":scr, string len = ncols + 2 + color" do
      str = "A" <> @max_str <> "B"

      res = [{str, :scr, [:blue]}] |> StrFmt.to_string()
      assert res == "\e[34mAaaaaaaaaaabbbbbbbb..ccccccccddddddddddB\e[0m"
      assert HelperTest.fit_in_ncols?(res)
    end

    test "multiple str_fmt + 1 color" do
      res = ["\n", {"Bla", :str, [:blue]}, "\n"] |> StrFmt.to_string()

      assert res == "\n\e[34mBla\e[0m\n"
      assert HelperTest.fit_in_ncols?(res)
    end

    test "multiple str_fmt + 2 colors" do
      res = ["\n", {"Bla", :str, [:red]}, {"Out", :str, [:cyan]}] |> StrFmt.to_string()

      assert res == "\n\e[31mBla\e[0m\e[36mOut\e[0m"
      assert HelperTest.fit_in_ncols?(res)
    end
  end
end
