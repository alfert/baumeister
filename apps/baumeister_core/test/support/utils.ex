defmodule Baumeister.Test.Utils do
  @moduledoc """
  Some utility functions for various tests
  """

  alias Baumeister.BaumeisterFile

  def create_bmf(cmd \\ "true") do
    {_, local_os} = :os.type()
    local_os = local_os |> Atom.to_string
    bmf = """
      os: #{local_os}
      language: elixir
      command: #{cmd}
    """
    {bmf, local_os}
  end

  def create_parsed_bmf(cmd \\ "true") do
    {src, os} = create_bmf(cmd)
    {src |> BaumeisterFile.parse!(), os}
  end

  def wait_for(pred) do
    case pred.() do
      false ->
        Process.sleep(1)
        wait_for(pred)
      _ -> true
    end
  end

end
