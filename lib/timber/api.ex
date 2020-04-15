defmodule Timber.API do
  alias Timber.Config

  @moduledoc false
  # This module is responsible for exposing interacting with the Timber API:
  #
  # http://docs.api.timber.io/

  # Support the legacy API keys that were source specific and did not require a source ID.
  def send_logs(provider, api_key, source_id, content_type, body, opts \\ [])

  def send_logs(provider, api_key, nil, content_type, body, opts) do
    case provider do
      "timber" -> do_send_logs_to_timber(api_key, nil, content_type, body, opts)
      "datadog" -> do_send_logs_to_datadog(api_key, nil, content_type, body, opts)
    end
  end

  def send_logs(provider, api_key, source_id, content_type, body, opts) do
    case provider == "timber" do
      true ->
        async = Keyword.get(opts, :async, false)
        host = Config.http_host()
        url = "#{host}/sources/#{source_id}/frames"
        headers = %{"Authorization" => "Bearer #{api_key}", "Content-Type" => content_type}
        request(:post, url, headers: headers, body: body, async: async)

      false ->
        raise "source_id not supported for non-Timber providers"
    end
  end

  defp do_send_logs_to_timber(api_key, nil, content_type, body, opts) do
    async = Keyword.get(opts, :async, false)
    host = Config.http_host()
    url = "#{host}/frames"
    auth_token = Base.encode64(api_key)
    headers = %{"Authorization" => "Basic #{auth_token}", "Content-Type" => content_type}
    request(:post, url, headers: headers, body: body, async: async)
  end

  defp do_send_logs_to_datadog(api_key, nil, _content_type, body, opts) do
    async = Keyword.get(opts, :async, false)
    host = Config.http_host()
    url = "#{host}"
    headers = %{"DD-API-KEY" => "#{api_key}", "Content-Type" => "application/json"}
    request(:post, url, headers: headers, body: body, async: async)
  end

  def handle_async_response(ref, msg) do
    http_client = Config.http_client()
    http_client.handle_async_response(ref, msg)
  end

  def wait_on_response(ref, timeout) do
    http_client = Config.http_client()
    http_client.wait_on_response(ref, timeout)
  end

  #
  # Util
  #

  defp request(method, url, opts) do
    http_client = Config.http_client()
    vsn = Application.spec(:timber, :vsn)
    user_agent = "timber-elixir/#{vsn}"

    headers =
      opts
      |> Keyword.get(:headers, %{})
      |> Map.put("User-Agent", user_agent)

    body = Keyword.get(opts, :body)

    if Keyword.get(opts, :async, false) do
      http_client.async_request(method, url, headers, body)
    else
      http_client.request(method, url, headers, body)
    end
  end
end
