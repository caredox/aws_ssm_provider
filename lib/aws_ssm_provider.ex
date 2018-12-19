defmodule AwsSsmProvider do
  @moduledoc """
  Populate run time application variables from a file produced by a call to AWS SSM
  """
  use Mix.Releases.Config.Provider

  # def start([config_path]) do
  def init([config_path]) do
    # Helper which expands paths to absolute form
    # and expands env vars in the path of the form `${VAR}`
    # to their value in the system environment
    {:ok, config_path} = Provider.expand_path(config_path)
    # All applications are already loaded at this point
    if File.exists?(config_path) do
      {:ok, lines} = File.read(config_path)
      json = Jason.decode!(lines)
      set_vars(json)
    else
      :ok
    end
  end

  defp set_vars([]), do: nil

  defp set_vars([head | tail]) do
    val = translate_values(head["Value"])
    key_list = String.split(head["Name"], "/", trim: true)
    atom_key_list = Enum.map(key_list, fn x -> String.to_atom(x) end)
    persist(val, atom_key_list)
    set_vars(tail)
  end

  defp persist(val, [_env, _project, app, head_key | [:FromSystem]]) do
    Application.put_env(app, head_key, System.get_env(val))
  end

  defp persist(val, [_env, _project, app, head_key | [:Integer]]) do
    Application.put_env(app, head_key, elem(Integer.parse(val), 0))
  end

  defp persist(val, [_env, _project, app, head_key | []]) do
    Application.put_env(app, head_key, val)
  end

  defp persist(val, [_env, _project, app, head_key | tail_keys]) do
    app_vars = Application.get_env(app, head_key) || []
    Application.put_env(app, head_key, get_nested_vars(app_vars, tail_keys, val))
  end

  defp persist(_val, _), do: nil

  defp get_nested_vars(parent_vars, [head], value) do
    [{head, value} | parent_vars]
  end

  defp get_nested_vars(parent_vars, key_list, value) do
    parent_vars = parent_vars
    [head | tail] = key_list
    nested_case(tail, [{head, value} | parent_vars])
  end

  defp nested_case([:FromSystem], [{head, value} | parent_vars]) do
    [{head, System.get_env(value)} | parent_vars]
  end

  defp nested_case([:Integer], [{head, value} | parent_vars]) do
    [{head, elem(Integer.parse(value), 0)} | parent_vars]
  end

  defp nested_case(tail, [{head, value} | parent_vars]) do
    curr_vars = parent_vars[head] || []
    [{head, get_nested_vars(curr_vars, tail, value)} | parent_vars]
  end

  defp translate_values(v) do
    Map.get(translations(), v, v)
  end

  defp translations do
    %{
      "true" => true,
      "false" => false
    }
  end
end
