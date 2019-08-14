# aws_ssm_provider

A configuration provider for Mix which handles AWS SSM parameters.

## Usage

This package is intended to be used in conjunction with Mix Config.Providers in Elixir 1.9+

To generate the file the config provider will read, run a command similar to

```bash
aws --region us-east-1 ssm get-parameters-by-path --path "/${SECRETS_PATH}/YOUR_PROJECT/" --recursive --with-decryption --query "Parameters[]" \
    > /etc/app_secrets.json
```

AWS recommends the path of the parameter keys follow a pattern similar to `/environment/project/service/config_key`

For example, a typical path you might set in SSM for your elixir project would be `/production/myApp/redix/port`

### Shared Configs

In order to share configs across environments, aws_ssm_provider looks for the magic string `host_app` and replaces it with the environment variable `APP_NAME`

If you had an SSM config that looked like `/production/my_project/host_app/shared_config`, and your environment had a `APP_NAME` variable that was `my_otp_app` then the `shared_config` value would be placed in your app called `my_otp_app`.

### Nesting

This package supports setting application variables that are keyword lists. For example, the path `/production/myApp/myWebApp/database/connection/port` would result in a myWebApp application variable like this

```elixir
[
    database: [
        connection: [
            port: yourValue
        ]
    ]
]
```

### Type Handling

All SSM keys are returned as strings. If you want to set your value as another type, please see the supported types below.

#### Integers

To set an integer in your application config, simply end your SSM path in `/Integer`. For example, if you wanted your port to be `4000` and not `"4000"`, your SSM key would look like `/staging/myApp/port/Integer`

#### Regular Expressions

To set a regex in your application config, simply end your SSM path in `/Regex`. For example, if you wanted a fileName config to match `"2019.csv"`, your SSM key would look like `/staging/myApp/fileName/Regex`. The value you enter in SSM would be

```bash
(\\d{4}.csv)
```

Notice the parantheses and the escape character for the back slash.

#### Arrays

To set an integer in your application config, simply end your SSM path in `/JsonArray`. For example, if you wanted an array of login keys, your SSM key would look like `/staging/myApp/login_keys/JsonArray`. Each item in your array can be a String (default), or Regex. If you enter your values into the Parameter Store UI in the AWS console, it will handle escaping some characters for you, so you'd want to enter something like `["^.*specialKey\\.secret$/Regex","exact-match-key"]`.

#### Booleans

`"true"` and `"false"` are translated to their respective boolean values.

### System Vars

If you have a variable in your system environment that you want injected in an application configuration, simply end your path in `/FromSystem`, for example: `/staging/myApp/database/host/FromSystem`. When using the system vars, the value of your SSM parameter will be the name of the environment variable. In this case, something like `DB_HOST`.

## Installation

The correct version for your needs depends on the version of Distillery or Elixir your project uses:

- For Distillery versions `2.0.14` and earlier, you want `{:aws_ssm_provider, "~> 0.2.1"}`.
- For Distillery versions `2.1.0` and later, you want `{:aws_ssm_provider, "~> 1.0.0"}`.
- For Elixir versions `1.9` and later (without Distillery), you want `{:aws_ssm_provider, "~> 3.0.0"}`.

The package can be installed by adding `aws_ssm_provider` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aws_ssm_provider, "~> 3.0.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/aws_ssm_provider](https://hexdocs.pm/aws_ssm_provider).
