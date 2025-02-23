defmodule Downstream do
  @moduledoc """
  `Downstream` is an Elixir client for streaming downloads via GET or POST requests,
  by relying on `HTTPoison`.

  `Downstream` is simple to use, just pass it a URL and an IO device:
  """

  alias Downstream.{Download, Error, Response}

  @request_timeout 60_000

  @spec start() :: {atom, any}
  def start(), do: :application.ensure_all_started(:downstream)

  @spec get(binary, IO.device(), Keyword.t()) :: {:ok, Response.t()} | {:error, Error.t()}
  @doc ~S"""
  Downloads from a given URL with a GET request.

  Returns `{:ok, %Downstream.Response{}}` if the download is successful, and
  `{:error, %Downstream.Error{}}` otherwise.
  """
  def get(url, io_device, options \\ []) do
    timeout = Keyword.get(options, :timeout, @request_timeout)
    headers = Keyword.get(options, :headers, [])
    http_options = Keyword.get(options, :http_options, [])

    download_task =
      Task.async(Download, :stream, [
        %{type: :get, io_device: io_device, options: options}
      ])

    httpoison_options = Keyword.merge(http_options, stream_to: download_task.pid, follow_redirect: true)

    HTTPoison.get!(url, headers, httpoison_options)

    try do
      Task.await(download_task, timeout)
    catch
      :exit, _ -> {:error, %Error{reason: :timeout}}
    end
  end

  @doc ~S"""
  Downloads from the given URL with a GET request, raising an exception in the case of failure.

  If the request succeeds, a Downstream.Response struct is returned.
  """
  @spec get!(binary, IO.device(), Keyword.t()) :: Response.t() | Error.t()
  def get!(url, io_device, options \\ []) do
    case get(url, io_device, options) do
      {:ok, response} -> response
      {:error, %Error{reason: reason}} -> raise Error, reason: reason
    end
  end

  @spec post(binary, IO.device(), binary | {atom, any}, Keyword.t()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  @doc ~S"""
  Downloads from a given URL with a POST request.

  Returns `{:ok, %Downstream.Response{}}` if the download is successful, and
  `{:error, %Downstream.Error{}}` otherwise.
  """
  def post(url, io_device, body \\ "", options \\ []) do
    timeout = Keyword.get(options, :timeout, @request_timeout)
    headers = Keyword.get(options, :headers, [])
    http_options = Keyword.get(options, :http_options, [])

    download_task =
      Task.async(Download, :stream, [
        %{type: :post, io_device: io_device, body: body, options: options}
      ])

    httpoison_options = Keyword.merge(http_options, stream_to: download_task.pid, follow_redirect: true)

    HTTPoison.post!(url, body, headers, httpoison_options)

    try do
      Task.await(download_task, timeout)
    catch
      :exit, _ -> {:error, %Error{reason: :timeout}}
    end
  end

  @spec post!(binary, IO.device(), binary | {atom, any}, Keyword.t()) :: Response.t() | Error.t()
  @doc ~S"""
  Downloads from the given URL with a POST request, raising an exception in the case of failure.

  If the request succeeds, a Downstream.Response struct is returned.
  """
  def post!(url, io_device, body \\ "", options \\ []) do
    case post(url, io_device, body, options) do
      {:ok, response} -> response
      {:error, %Error{reason: reason}} -> raise Error, reason: reason
    end
  end
end
