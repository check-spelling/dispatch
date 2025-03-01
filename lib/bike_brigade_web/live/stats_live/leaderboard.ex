defmodule BikeBrigadeWeb.StatsLive.Leaderboard do
  use BikeBrigadeWeb, :live_view
  alias BikeBrigadeWeb.StatsLive.NavComponent
  alias BikeBrigade.Stats

  alias BikeBrigade.LocalizedDateTime

  alias BikeBrigadeWeb.Components.Icons

  defmodule Options do
    # This pattern is from  https://mattpruitt.com/articles/phoenix-forms-with-ecto-embedded-schema
    # evaluating about using it more
    use BikeBrigade.Schema
    import Ecto.Changeset
    import EctoEnum

    defenum(SortBy,
      rider_name: "rider_name",
      campaigns: "campaigns",
      deliveries: "deliveries",
      distance: "distance"
    )

    defenum(SortOrder, asc: "asc", desc: "desc")
    defenum(Period, all_time: "all_time", select: "select")

    @required [:sort_by, :sort_order, :period]
    @attributes @required ++ [:start_date, :end_date]
    @primary_key false

    embedded_schema do
      field :sort_by, SortBy, default: :campaigns
      field :sort_order, SortOrder, default: :desc
      field :period, Period, default: :all_time
      field :start_date, :date
      field :end_date, :date
    end

    def default() do
      # Default dates need to be computed at runtime so we have to the date computation here
      end_date = LocalizedDateTime.today()
      start_date = Date.add(end_date, -7)
      %__MODULE__{start_date: start_date, end_date: end_date}
    end

    def changeset(options, attrs \\ %{}) do
      cast(options, attrs, @attributes)
      |> validate_required(@required)
      |> maybe_move_end_date()
    end

    def update(options, attrs) do
      options
      |> changeset(attrs)
      |> apply_action(:update)
    end

    defp maybe_move_end_date(changeset) do
      with {_, start_date} <- fetch_field(changeset, :start_date),
           {_, end_date} <- fetch_field(changeset, :end_date),
           :lt <- Date.compare(end_date, start_date) do
        put_change(changeset, :end_date, start_date)
      else
        _ -> changeset
      end
    end
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    options = Options.default()

    {:ok,
     socket
     |> assign(:page, :stats)
     |> assign(:page_title, "Stats")
     |> assign(:options, options)
     |> assign_stats()}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("sort", options_params, socket) do
    socket =
      case Options.update(socket.assigns.options, options_params) do
        {:ok, options} -> assign(socket, :options, options) |> assign_stats()
        {:error, _} -> put_flash(socket, :error, "Invalid options selected")
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("update-options", %{"options" => options_params}, socket) do
    socket =
      case Options.update(socket.assigns.options, options_params) do
        {:ok, options} -> assign(socket, :options, options) |> assign_stats()
        {:error, _} -> put_flash(socket, :error, "Invalid options selected")
      end

    {:noreply, socket}
  end

  defp assign_stats(socket) do
    IO.inspect socket.assigns.options
    stats =
      case socket.assigns.options do
        %Options{period: :all_time, sort_by: sort_by, sort_order: sort_order} ->
          Stats.rider_leaderboard(sort_by, sort_order)

        %Options{
          period: :select,
          sort_by: sort_by,
          sort_order: sort_order,
          start_date: start_date,
          end_date: end_date
        } ->
          Stats.rider_leaderboard(sort_by, sort_order, start_date, end_date)
      end

    socket
    |> assign(:stats, stats)
  end

  defp sort_icon(assigns = %{field: field, options: %Options{sort_by: field, sort_order: :desc}}) do
    ~H"""
    <a phx-click="sort" phx-value-sort_by={@field} phx-value-sort_order="asc" href="#" class="pl-2 text-gray-500 hover:text-gray-700">
      <Icons.sort order={:desc} />
    </a>
    """
  end

  defp sort_icon(assigns = %{field: field, options: %Options{sort_by: field, sort_order: :asc}}) do
    ~H"""
    <a phx-click="sort" phx-value-sort_by={@field} phx-value-sort_order="desc" href="#" class="pl-2 text-gray-500 hover:text-gray-700">
      <Icons.sort order={:asc} />
    </a>
    """
  end

  defp sort_icon(assigns) do
    ~H"""
    <a phx-click="sort" phx-value-sort_by={@field} phx-value-sort_order="asc" href="#" class="pl-2 text-gray-300 hover:text-gray-700">
      <Icons.sort order={:desc} />
    </a>
    """
  end

  defp download_path(options) do
    %{
      period: period,
      sort_by: sort_by,
      sort_order: sort_order,
      start_date: start_date,
      end_date: end_date
    } = options

    case period do
      :all_time ->
        Routes.export_stats_path(BikeBrigadeWeb.Endpoint, :leaderboard,
          sort_by: options.sort_by,
          sort_order: options.sort_order
        )

      :select ->
        Routes.export_stats_path(BikeBrigadeWeb.Endpoint, :leaderboard,
          sort_by: sort_by,
          sort_order: sort_order,
          start_date: start_date,
          end_date: end_date
        )
    end
  end
end
