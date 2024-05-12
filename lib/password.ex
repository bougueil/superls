defmodule Superls.Password do
  # https://dev.to/tizpuppi/password-input-in-elixir-31oo
  # Password prompt that hides input by every 1ms
  # clearing the line with stderr
  @moduledoc false

  def io_get_passwd,
    do: get(" enter password: ")

  def get(prompt) do
    pid = spawn_link(fn -> loop(prompt) end)
    ref = make_ref()
    value = IO.gets("#{prompt} ")

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)
    String.trim(value)
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        IO.write(:standard_error, "\e[2K\r#{prompt} ")
        loop(prompt)
    end
  end
end
