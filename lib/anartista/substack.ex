defmodule Anartista.Substack do
  use GenServer
  import SweetXml

  @feed_url "https://apalvarezvega.substack.com/feed"
  @refresh_ms :timer.hours(1)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc "Devuelve la lista de posts cacheados (puede ser [])"
  def posts(limit \\ 3) do
    case :ets.lookup(__MODULE__, :posts) do
      [{:posts, posts}] -> Enum.take(posts, limit)
      [] -> []
    end
  end

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [:named_table, :set, :protected, read_concurrency: true])
    send(self(), :refresh)
    {:ok, nil}
  end

  @impl true
  def handle_info(:refresh, state) do
    fetch_and_store()
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, state}
  end

  defp fetch_and_store do
    case Req.get(@feed_url, retry: false, receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} ->
        :ets.insert(__MODULE__, {:posts, parse_feed(body)})

      _ ->
        # Si falla, conservamos lo que ya había en cache
        :ok
    end
  rescue
    _ -> :ok
  end

  defp parse_feed(xml) do
    xml
    |> xpath(~x"//item"l,
      title: ~x"./title/text()"s,
      link: ~x"./link/text()"s,
      description: ~x"./description/text()"s,
      pub_date: ~x"./pubDate/text()"s,
      image: ~x"./enclosure/@url"s
    )
    |> Enum.map(fn post ->
      post
      |> Map.update!(:title, &clean_text/1)
      |> Map.update!(:description, &clean_text/1)
      |> Map.update!(:pub_date, &format_date/1)
    end)
  end

  defp clean_text(text) do
    text
    |> HtmlEntities.decode()
    |> String.replace(~r/<[^>]*>/, "")
    |> String.trim()
  end

  defp format_date(rfc822) do
    # "Wed, 09 Jul 2025 14:00:00 GMT" -> "9 de julio 2025"
    with [_, day, month, year | _] <- String.split(rfc822, [" ", ","], trim: true) do
      meses = %{
        "Jan" => "enero",
        "Feb" => "febrero",
        "Mar" => "marzo",
        "Apr" => "abril",
        "May" => "mayo",
        "Jun" => "junio",
        "Jul" => "julio",
        "Aug" => "agosto",
        "Sep" => "septiembre",
        "Oct" => "octubre",
        "Nov" => "noviembre",
        "Dec" => "diciembre"
      }

      "#{String.to_integer(day)} de #{meses[month]} #{year}"
    else
      _ -> ""
    end
  end
end
