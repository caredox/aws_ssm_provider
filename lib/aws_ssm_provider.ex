defmodule AwsSsmProvider do
  @moduledoc """
  Populate run time application variables from a file produced by a call to AWS SSM
  """

  @behaviour Config.Provider

  @replacement_key :host_app
  @app_name_env_var "APP_NAME"

  def init(path) when is_binary(path), do: path

  def load(_current_configuration, config_path) do
    {:ok, _} = Application.ensure_all_started(:jason)

    app_name = fetch_app_name()

    if File.exists?(config_path) do
      File.read!(config_path)
      |> Jason.decode!()
      |> set_vars(app_name)
    else
      :error
    end
  end

  defp fetch_app_name do
    case System.get_env(@app_name_env_var) do
      nil -> nil
      "" -> nil
      app_name -> String.to_atom(app_name)
    end
  end

  defp set_vars([], _), do: :ok

  defp set_vars([head | tail], app_name) do
    val = translate_values(head["Value"])

    head["Name"]
    |> String.split("/", trim: true)
    |> Enum.map(&String.to_atom/1)
    |> remove_prefix_keys
    |> set_app_name(app_name)
    |> persist(val)

    set_vars(tail, app_name)
  end

  defp set_app_name(name, nil), do: name
  # If an app_name was provided to the config provider,
  # then we want to replace the content retrieved from SSM if it was set to host_app.
  # This is useful when we pull shared configs, but need to assign it to an app not named :host_app.
  defp set_app_name(name, app_name) when is_atom(app_name) do
    [head | tail] = name

    if head == @replacement_key do
      [app_name | tail]
    else
      name
    end
  end

  defp remove_prefix_keys([_env, _project | tail]), do: tail

  defp persist([app, head_key | [:FromSystem]], val) do
    Application.put_env(app, head_key, System.get_env(val))
  end

  defp persist([app, head_key | [:Integer]], val) do
    Application.put_env(app, head_key, String.to_integer(val))
  end

  defp persist([app, head_key | [:Regex]], val) do
    with {:ok, regex} <- Regex.compile(val) do
      Application.put_env(app, head_key, regex)
    end
  end

  defp persist([app, head_key | [:JsonArray]], val) do
    list_val = val |> Jason.decode!() |> Enum.map(&handle_array_val/1)
    Application.put_env(app, head_key, list_val)
  end

  defp persist([app, head_key | []], val) do
    Application.put_env(app, head_key, val)
  end

  defp persist([app, head_key | tail_keys], val) do
    app_vars = Application.get_env(app, head_key) || []
    Application.put_env(app, head_key, set_nested_vars(app_vars, tail_keys, val))
  end

  defp handle_array_val(val) when is_binary(val) do
    case String.split(val, "/Regex") do
      [str] -> str
      [regex, _b] -> regex |> Regex.compile!()
    end
  end

  defp handle_array_val(val) when is_list(val) do
    val |> Enum.map(&handle_array_val/1)
  end

  defp handle_array_val(val) when is_integer(val), do: val

  defp set_nested_vars(parent_vars, [head], value) do
    Keyword.drop(parent_vars, [head])
    |> List.flatten([{head, value}])
  end

  defp set_nested_vars(parent_vars, [head | tail], value) do
    nested_case(tail, [{head, value} | parent_vars])
  end

  defp nested_case([:FromSystem], [{head, value} | parent_vars]) do
    Keyword.drop(parent_vars, [head])
    |> List.flatten([{head, System.get_env(value)}])
  end

  defp nested_case([:Integer], [{head, value} | parent_vars]) do
    Keyword.drop(parent_vars, [head])
    |> List.flatten([{head, String.to_integer(value)}])
  end

  defp nested_case([:Regex], [{head, value} | parent_vars]) do
    with {:ok, regex} <- Regex.compile(value) do
      Keyword.drop(parent_vars, [head])
      |> List.flatten([{head, regex}])
    end
  end

  defp nested_case([:JsonArray], [{head, value} | parent_vars]) do
    list_val = value |> Jason.decode!() |> Enum.map(&handle_array_val/1)

    Keyword.drop(parent_vars, [head])
    |> List.flatten([{head, list_val}])
  end

  defp nested_case(tail, [{head, value} | parent_vars]) do
    curr_vars = parent_vars[head] || []
    [{head, set_nested_vars(curr_vars, tail, value)} | parent_vars]
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
