defmodule AwsSsmProvider do
  @moduledoc """
  Populate run time application variables from a file produced by a call to AWS SSM
  """

  @behaviour Config.Provider

  @replacement_key :host_app
  @app_name_env_var "APP_NAME"

  def init(path) when is_binary(path), do: path

  def load(initial_configs, config_path) do
    {:ok, _} = Application.ensure_all_started(:jason)

    app_name = fetch_app_name()

    with {:ok, content} <- File.read(config_path),
         {:ok, ssm_configs} <- Jason.decode(content),
         {:ok, configs} <- parse_ssm_config(ssm_configs, app_name) do
      Config.Reader.merge(initial_configs, configs)
    else
      {:error, err} ->
        msg = error_message(err, config_path)
        throw({:error, msg})

      err ->
        throw({:unknown_error, err})
    end
  end

  defp fetch_app_name do
    case System.get_env(@app_name_env_var) do
      nil -> nil
      "" -> nil
      app_name -> String.to_atom(app_name)
    end
  end

  defp parse_ssm_config(ssm_configs, app_name) do
    configs =
      ssm_configs
      |> Enum.map(&lex_ssm_entry(&1, app_name))
      |> Enum.map(&build_config_branch/1)
      |> Enum.reduce([], fn new_config, prev_configs ->
        Config.Reader.merge(prev_configs, new_config)
      end)

    {:ok, configs}
  end

  @type lexed_entry :: {path :: [atom()], value :: term()}
  @spec lex_ssm_entry(%{String.t() => String.t(), String.t() => any()}, String.t()) ::
          lexed_entry()
  defp lex_ssm_entry(entry, app_name) do
    value = entry["Value"]

    path =
      entry["Name"]
      |> String.split("/", trim: true)
      |> Enum.map(&String.to_atom/1)
      |> remove_prefix_keys()
      |> set_app_name(app_name)

    {path, value}
  end

  # Takes a keypath and a value to a branch of a config tree. E.g.,
  #
  #   build_config_branch({[:a, :b, :c], :value})
  #   => [a: [b: [c: :value]]]
  defp build_config_branch({path, value}) do
    path
    |> Enum.reverse()
    |> Enum.reduce(value, &convert_value/2)
  end

  # Convert the value, based on the final key in the path
  # If thefinal key is not a special conversion keyword,
  # just return the final segment of the path to the value
  defp convert_value(key, value) do
    case key do
      :FromSystem -> System.get_env(value)
      :Integer -> String.to_integer(value)
      :Regex -> Regex.compile!(value)
      :JsonArray -> convert_json_array(value)
      key -> [{key, translate_value(value)}]
    end
  end

  defp set_app_name(name, nil), do: name
  # If an app_name was provided to the config provider,
  # then we want to replace the content retrieved from SSM if it was set to host_app.
  # This is useful when we pull shared configs, but need to assign it to an app not named :host_app.
  defp set_app_name([head | tail] = name, app_name) when is_atom(app_name) do
    if head == @replacement_key, do: [app_name | tail], else: name
  end

  defp remove_prefix_keys([_env, _project | tail]), do: tail

  defp convert_json_array(v), do: v |> Jason.decode!() |> Enum.map(&handle_array_val/1)

  defp handle_array_val(val) when is_integer(val), do: val
  defp handle_array_val(val) when is_list(val), do: val |> Enum.map(&handle_array_val/1)

  defp handle_array_val(val) when is_binary(val) do
    case String.split(val, "/Regex") do
      [str] -> str
      [regex, _b] -> regex |> Regex.compile!()
    end
  end

  defp translate_value(v), do: Map.get(translations(), v, v)

  defp translations do
    %{
      "true" => true,
      "false" => false
    }
  end

  # ERROR HANDLING
  defp error_message(err, path) do
    if is_file_read_error?(err) do
      file_error_message(err, path)
    else
      case err do
        %Jason.DecodeError{} -> json_error_message(err, path)
        _ -> err
      end
    end
  end

  defp is_file_read_error?(err) do
    file_read_errors = [:enoent, :eacces, :eisdir, :enotdir, :enomem]
    Enum.member?(file_read_errors, err)
  end

  defp file_error_message(err, path) do
    file_error = :file.format_error(err)
    "Error reading file #{path}: #{file_error}"
  end

  defp json_error_message(err, path) do
    json_err = Jason.DecodeError.message(err)
    "Error decoding JSON in file #{path}: #{json_err}"
  end
end
