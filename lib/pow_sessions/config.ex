defmodule PhoenixApiToolkit.PowSessions.Config do
  def process_config(config), do: Pow.Config.get(config, :phoenix_api_toolkit)
  def access_salt(config), do: config[:access_token_salt] || "access_token"
  def access_ttl(config), do: config[:access_token_ttl]
  def access_opts(config), do: [key_digest: config[:access_token_key_digest] || :sha256]

  def access_verify_opts(config),
    do: Keyword.put(access_opts(config), :max_age, access_ttl(config))

  def refresh_salt(config), do: config[:refresh_token_salt] || "refresh_token"
  def refresh_ttl(config), do: config[:refresh_token_ttl]
  def refresh_opts(config), do: [key_digest: config[:refresh_token_key_digest] || :sha512]

  def refresh_verify_opts(config),
    do: Keyword.put(refresh_opts(config), :max_age, refresh_ttl(config))

  def refresh_sig_cookie_name(config), do: config[:refresh_signature_cookie_name]

  def refresh_sig_cookie_opts(config),
    do: [
      http_only: true,
      extra: "SameSite=Strict",
      secure: true,
      path: config[:refresh_path]
    ]

  def access_sig_cookie_name(config), do: config[:access_signature_cookie_name]

  def access_sig_cookie_opts(_config),
    do: [
      http_only: true,
      extra: "SameSite=Strict",
      secure: true
    ]

  def session_store(config), do: config[:session_store]
end
