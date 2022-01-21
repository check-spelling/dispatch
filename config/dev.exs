import Config

config :bike_brigade, :environment, :dev
config :bike_brigade, :app_env, "development"

# Configure your database
config :bike_brigade, BikeBrigade.Repo,
  username: System.get_env("POSTGRES_USERNAME") || "postgres",
  password: "postgres",
  database: "bike_brigade_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :bike_brigade, BikeBrigadeWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :bike_brigade, BikeBrigadeWeb.Endpoint,
  live_reload: [
    iframe_attrs: [class: "hidden"],
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/bike_brigade_web/(live|views)/.*(ex)$",
      ~r"lib/bike_brigade_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Disable the extremely annoying debug logging for the spreadsheet library
config :logger,
  compile_time_purge_matching: [
    [application: :elixir_google_spreadsheets, level_lower_than: :info]
  ]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Don't run importers
config :bike_brigade, BikeBrigade.Importers.Runner, start: false

config :honeybadger,
  environment_name: :dev

# We use the same phone number for our authentication and regular messaging by they are configurable separately for now
config :bike_brigade, BikeBrigade.Messaging, phone_number: {:system, "PHONE_NUMBER"}
config :bike_brigade, BikeBrigade.AuthenticationMessenger, phone_number: {:system, "PHONE_NUMBER"}

case System.get_env("SLACK_WEBHOOK_URL") do
  nil ->
    config :bike_brigade, :slack,
      webhook_url: "http://example.com/fake-slack-api",
      adapter: BikeBrigade.SlackApi.FakeSlack

  url ->
    config :bike_brigade, :slack,
      webhook_url: url,
      adapter: BikeBrigade.SlackApi.Http
end

case {System.get_env("TWILIO_ACCOUNT_SID"), System.get_env("TWILIO_AUTH_TOKEN"),
      System.get_env("TWILIO_STATUS_CALLBACK")} do
  {sid, token, url} when is_binary(sid) and is_binary(token) and is_binary(url) ->
    config :ex_twilio,
      account_sid: sid,
      auth_token: token

    config :bike_brigade, :sms_service,
      adapter: BikeBrigade.SmsService.Twilio,
      status_callback_url: url

  {_, _, _} ->
    config :bike_brigade, :sms_service,
      adapter: BikeBrigade.SmsService.FakeSmsService,
      status_callback_url: :local
end

case System.get_env("GOOGLE_MAPS_API_KEY") do
  api_key when is_binary(api_key) and api_key != "" ->
    config :bike_brigade, :geocoder, adapter: BikeBrigade.Geocoder.LibLatLonGeocoder

  _ ->
    config :bike_brigade, :geocoder,
      adapter: {BikeBrigade.Geocoder.FakeGeocoder, [locations: :from_seeds]}
end

case System.get_env("GOOGLE_SERVICE_JSON") do
  json when is_binary(json) and json != "" ->
    config :bike_brigade, BikeBrigade.Google, credentials: json

    case System.get_env("GOOGLE_STORAGE_BUCKET") do
      nil ->
        config :bike_brigade, :media_storage,
          adapter: BikeBrigade.MediaStorage.LocalMediaStorage,
          bucket: "bike-brigade-media"

      bucket ->
        config :bike_brigade, :media_storage,
          adapter: BikeBrigade.MediaStorage.GoogleMediaStorage,
          bucket: bucket
    end

  _no_json ->
    config :bike_brigade, :media_storage,
      adapter: BikeBrigade.MediaStorage.FakeMediaStorage,
      bucket: System.get_env("GOOGLE_STORAGE_BUCKET", "bike-brigade-fake")
end

case System.get_env("MAILCHIMP_API_KEY") do
  nil ->
    config :bike_brigade, :mailchimp, adapter: BikeBrigade.MailchimpApi.FakeMailchimp

  url ->
    config :bike_brigade, :mailchimp, adapter: BikeBrigade.MailchimpApi.FakeMailchimp
end
