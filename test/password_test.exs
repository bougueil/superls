defmodule Superls.PasswordTest do
  use ExUnit.Case

  @msg "super long message"

  test "encrypt decrypt" do
    encrypted = Superls.encrypt(@msg, "password")
    {:ok, msg} = Superls.decrypt(encrypted, "password")
    assert msg == @msg
  end

  test "encrypt really does smthing" do
    msg = Superls.encrypt(@msg, "password")
    refute msg == @msg
  end
end
