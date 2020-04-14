defmodule AwsSsmProviderTest do
  use ExUnit.Case
  doctest AwsSsmProvider

  setup_all do
    System.put_env("APP_NAME", "aws_ssm_provider")

    empty_configs = Path.join([__DIR__, "fixtures", "empty_configs.json"])
    app_configs = Path.join([__DIR__, "fixtures", "app_configs.json"])
    global_configs = Path.join([__DIR__, "fixtures", "global_configs.json"])
    invalid_configs = Path.join([__DIR__, "fixtures", "invalid_configs.json"])
    initial_config = []

    %{
      initial_config: initial_config,
      config_files: %{
        empty: empty_configs,
        app: app_configs,
        global: global_configs
      },
      invalid_config: invalid_configs
    }
  end

  defp cors_origins do
    [
      ~r/^https?:\/\/localhost:8081$/,
      ~r/^https?:\/\/.*mydomain\.com$/,
      "http://myapp.elb.amazonaws.com"
    ]
  end

  defp repo_vars do
    [
      nested: [shared_with_nested: "44773"],
      shared_with_nested: "39202",
      cors_origins: cors_origins(),
      port: 3306,
      pool_timeout: 60000,
      pattern: ~r/(\d{4}.csv)/
    ]
  end

  defp nested_vars do
    [
      nested_duplicate_string: "dup_string_4",
      nested_duplicate_integer: 4,
      nested_duplicate_regex: ~r/(\d{3}.csv)/,
      nested_duplicate_system_var: System.get_env("USER"),
      nested_duplicate_json_array: [9, 2, 2]
    ]
  end

  describe "when loading config files" do
    test "an empty config yields the empty list", context do
      assert AwsSsmProvider.load(context.initial_config, context.config_files.empty) == []
    end

    test "a valid config returns a keyword list", context do
      Enum.each(context.config_files, fn {_, config_file} ->
        assert Keyword.keyword?(AwsSsmProvider.load(context.initial_config, config_file))
      end)
    end

    test "a valid config maintains the initial config when there are no overlaps", context do
      initial_config = [aws_ssm_provider: [initial_config: "existing value"]]
      result = AwsSsmProvider.load(initial_config, context.config_files.app)
      assert result[:aws_ssm_provider][:initial_config] == "existing value"
    end

    test "a nonexisting file throws a clear error message", context do
      fake_file = "a_nonexistant_file.json"

      try do
        AwsSsmProvider.load(context.initial_config, fake_file)
      catch
        caught ->
          assert {:error, msg} = caught
          assert msg == "Error reading file #{fake_file}: no such file or directory"
      end
    end

    test "a file with invalid JSON throws a clear error message", context do
      try do
        AwsSsmProvider.load(context.initial_config, context.invalid_config)
      catch
        caught ->
          assert {:error, msg} = caught

          assert msg ==
                   "Error decoding JSON in file #{context.invalid_config}: unexpected end of input at position 50"
      end
    end
  end

  describe "in the parsed app config" do
    setup context do
      %{config: AwsSsmProvider.load(context.initial_config, context.config_files.app)}
    end

    test "string_val is set at the root level", context do
      assert context.config[:aws_ssm_provider][:string_val] == "a string"
    end

    test "integer_val is set at the root level", context do
      assert context.config[:aws_ssm_provider][:int_val] == 1001
    end

    test "regex is set on root level", context do
      assert context.config[:aws_ssm_provider][:use_logger4] == ~r/(\d{4}.csv)/
    end

    test "json array is set on root level", context do
      assert context.config[:aws_ssm_provider][:cors_origins] == cors_origins()
    end

    test "system variable is set on root level", context do
      assert context.config[:aws_ssm_provider][:home] == System.get_env("HOME")
    end

    test "string is set on nested level", context do
      assert context.config[:aws_ssm_provider][:nested][:string_val] == "1003"
    end

    test "integer is set on nested level", context do
      assert context.config[:aws_ssm_provider][:nested][:int_val] == 1002
    end

    test "regex is set on nested level", context do
      assert context.config[:aws_ssm_provider][:nested][:file_name] == ~r/(\d{5}.csv)/
    end

    test "json array is set on nested level", context do
      assert context.config[:aws_ssm_provider][CaredoxGraphql.Repo][:cors_origins] ==
               cors_origins()
    end

    test "system variable is set on nested level", context do
      assert context.config[:aws_ssm_provider][:nested][:user] == System.get_env("USER")
    end

    test "true/false are converted to booleans", context do
      assert context.config[:aws_ssm_provider][:use_logger] == true
    end

    test "application variables from sample json are set in nested ", context do
      expected = repo_vars()
      actual = context.config[:aws_ssm_provider][CaredoxGraphql.Repo]
      assert Keyword.equal?(expected, actual)
    end

    test "regex patterns are usable", context do
      pattern = context.config[:aws_ssm_provider][CaredoxGraphql.Repo][:pattern]
      assert Regex.match?(pattern, "2019.csv")
    end

    test "regex patterns in list are usable", context do
      [_o1, origin2, _o3] = context.config[:aws_ssm_provider][:cors_origins]
      assert Regex.match?(origin2, "http://xyz.mydomain.com")
    end

    test "ints in jsonArray are usable", context do
      assert context.config[:aws_ssm_provider][:int_array] == [1, 8, 2]
    end

    test "ints in nested jsonArray are usable", context do
      assert context.config[:aws_ssm_provider][:nested][:int_array] == [7, 0, 2]
    end

    test "arrays in jsonArray are usable", context do
      assert context.config[:aws_ssm_provider][:nested_array] ==
               [2, "root_string", [3, "root_nested_string"]]
    end

    test "arrays in nested jsonArray are usable", context do
      assert context.config[:aws_ssm_provider][:nested][:nested_array] ==
               [9, "string", [8, "nested_string"]]
    end

    test "regex patterns in nested list are usable", context do
      [_o1, origin2, _o3] = context.config[:aws_ssm_provider][CaredoxGraphql.Repo][:cors_origins]
      assert Regex.match?(origin2, "http://xyz.mydomain.com")
    end

    test "regex patterns enforce special characters", context do
      [_o1, origin2, _o3] = context.config[:aws_ssm_provider][CaredoxGraphql.Repo][:cors_origins]
      refute Regex.match?(origin2, "http://xyz.mydomainPcom")
    end

    test "duplicate strings are overwritten at the root level config", context do
      assert context.config[:aws_ssm_provider][:duplicate_string] == "dup_string_2"
    end

    test "duplicate integers are overwritten at the root level config", context do
      assert context.config[:aws_ssm_provider][:duplicate_integer] == 2
    end

    test "duplicate regexes are overwritten at the root level config", context do
      assert context.config[:aws_ssm_provider][:duplicate_regex] == ~r/(\d{2}.csv)/
    end

    test "duplicate system vars are overwritten at the root level config", context do
      assert context.config[:aws_ssm_provider][:duplicate_system_var] == System.get_env("HOME")
    end

    test "duplicate JSON arrays are overwritten at the root level config", context do
      assert context.config[:aws_ssm_provider][:duplicate_json_array] == [6, 5, 4]
    end

    test "duplicate strings are overwritten in nested config", context do
      nested_duplicates = context.config[:aws_ssm_provider][:nested_dups]
      assert Keyword.equal?(nested_duplicates, nested_vars())
    end
  end

  describe "when loading the app config after the global config" do
    setup context do
      config =
        context.initial_config
        |> AwsSsmProvider.load(context.config_files.global)
        |> AwsSsmProvider.load(context.config_files.app)

      %{config: config}
    end

    test "the global var is overwritten by app config", context do
      assert "this was overwritten" == context.config[:aws_ssm_provider][:overwritten_config]
    end

    test "the global var was overwritten with key name starting with global/global", context do
      assert "app and env is global was overwritten" ==
               context.config[:aws_ssm_provider][:overwritten_app_and_env_config]
    end

    test "global var was overwritten when just the app was global", context do
      assert "app is global this was overwritten" ==
               context.config[:aws_ssm_provider][:overwritten_app_config]
    end

    test "global nested var overwritten nested", context do
      assert "this was overwritten nested" ==
               context.config[:aws_ssm_provider][:nested][:overwritten_nested_config]
    end

    test "global nested app var overwritten", context do
      assert "app is global nested was overwritten" ==
               context.config[:aws_ssm_provider][:nested][:overwritten_nested_app_config]
    end

    test "global nested app and env var overwritten", context do
      assert "app and env is global nested was overwritten" ==
               context.config[:aws_ssm_provider][:nested][:overwritten_nested_app_and_env_config]
    end

    test "unique global var is present", context do
      assert "from global" == context.config[:aws_ssm_provider][:unique_global_config]
    end

    test "unique global app var is present", context do
      assert "app is global from global" ==
               context.config[:aws_ssm_provider][:unique_global_app_config]
    end

    test "unique global app and env var is present", context do
      assert "app and env is global from global" ==
               context.config[:aws_ssm_provider][:unique_global_app_and_env_config]
    end

    test "nested unique global var is present", context do
      assert "nested from global" ==
               context.config[:aws_ssm_provider][:nested][:unique_nested_global_config]
    end

    test "nested unique global app var is present", context do
      assert "app is global nested from global" ==
               context.config[:aws_ssm_provider][:nested][:unique_nested_app_global_config]
    end

    test "nested unique global app and env var is present", context do
      assert "app and env is global nested from global" ==
               context.config[:aws_ssm_provider][:nested][
                 :unique_nested_app_and_env_global_config
               ]
    end

    test "root level capital atom is converted", context do
      assert CapitalAtom == context.config[:aws_ssm_provider][:capital_atom]
    end

    test "nested capital atom is converted", context do
      assert Nested.Capital.Atom ==
               context.config[:aws_ssm_provider][:nested][:nested_capital_atom]
    end

    test "root level lowercase atom is converted", context do
      assert :iAmAtom == context.config[:aws_ssm_provider][:lowercase_atom]
    end

    test "nested lowercase atom is converted", context do
      assert :nestedAtom == context.config[:aws_ssm_provider][:nested][:nested_lowercase_atom]
    end
  end
end
