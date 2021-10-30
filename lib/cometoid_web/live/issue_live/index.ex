defmodule CometoidWeb.IssueLive.Index do
  use CometoidWeb, :live_view

  alias Cometoid.CodeAdapter
  alias Cometoid.Repo.Tracker
  alias Cometoid.Repo.Writing
  alias Cometoid.Repo.People
  alias Cometoid.Model.Writing.Text
  alias Cometoid.Model.People.Person
  alias Cometoid.Model.Tracker.Issue
  alias Cometoid.Model.Tracker.Context
  alias CometoidWeb.Theme
  alias CometoidWeb.IssueLive.IssuesMachine

  @impl true
  def mount _params, _session, socket do
    {
      :ok,
      socket
      |> assign(Theme.get)
    }
  end

  def handle_event "switch-theme", %{ "name" => name }, socket do
    Theme.toggle!
    socket
    |> assign(Theme.get)
    |> return_noreply
  end

  def render(assigns) do
    Phoenix.View.render(CometoidWeb.IssueLive.IssuesView, "issues_view.html", assigns)
  end

  @impl true
  def handle_params params, url, socket do
    context_types = get_context_types params

    state = %{
      control_pressed: false,
      context_types: context_types,
      list_issues_done_instead_open: false,
      selected_secondary_contexts: [],
      selected_context_type: if length(context_types) == 1 do List.first(context_types) end
    }
    state = Map.merge socket.assigns, state # TODO swap params and use |>
    state = IssuesMachine.set_context_properties state, true
    state = IssuesMachine.set_issue_properties state

    socket = socket
      |> assign(state)
      |> assign(:view, params["view"])
      |> do_query(true)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_info {:modal_closed}, socket do
    socket
    |> assign(:live_action, :index)
    |> return_noreply
  end

  def handle_info {:select_secondary_contexts, selected_secondary_contexts}, socket do
    socket
    |> assign(:selected_secondary_contexts, selected_secondary_contexts)
    |> return_noreply
  end

  def handle_info {:after_edit_form_save, %{ context_id: context_id }}, socket do

    selected_context = Tracker.get_context! context_id # fetch latest important flag
    state = IssuesMachine.set_context_properties socket.assigns, selected_context.important
    state = IssuesMachine.set_issue_properties state

    socket
    |> assign(state)
    |> do_query
  end

  def handle_info {:after_edit_form_save, issue}, socket do

    state =
      IssuesMachine.set_context_properties socket.assigns
      |> Map.delete(:flash)

    socket
    |> assign(state)
    |> assign(:selected_issue, issue)
    |> do_query
  end

  defp apply_action(socket, :index, _params) do # ?
    socket
    |> assign(:issue, nil)
  end

  def handle_event "keydown", %{ "key" => key }, %{ assigns: %{ live_action: :index } } = socket do
    case key do
      "Escape" ->
        socket
        |> assign(:selected_secondary_contexts, [])
      "n" ->
        socket
        |> assign(:live_action, :new)
        |> assign(:issue, %Issue{})
      "Control" ->
        socket
          |> assign(:control_pressed, true)
      _ ->
        socket
    end
    |> return_noreply
  end

  def handle_event "keyup", %{ "key" => key }, socket do
    case key do
      "Control" ->
        socket
          |> assign(:control_pressed, false)
      _ ->
        socket
    end
    |> return_noreply
  end

  def handle_event("keydown", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event "delete_issue", %{ "id" => id }, socket do
    state = IssuesMachine.delete_issue to_state(socket), id
    socket
    |> assign(state)
    |> do_query
  end

  def handle_event "edit_issue", id, socket do

    {id, ""} = Integer.parse id

    socket
    |> assign(:issue, Tracker.get_issue!(id))
    |> assign(:live_action, :edit)
    |> return_noreply
  end

  def handle_event "link_issue", %{ "target" => id }, socket do
    socket
    |> assign(:selected_issue, Tracker.get_issue!(id))
    |> assign(:live_action, :link)
    |> return_noreply
  end

  def handle_event "edit_issue_description", _, socket do
    socket
    |> assign(:issue, Tracker.get_issue!(socket.assigns.selected_issue.id))
    |> assign(:live_action, :describe)
    |> return_noreply
  end

  def handle_event "create_new_issue", params, socket do
    socket
    |> assign(:issue, %Issue{})
    |> assign(:live_action, :new)
    |> return_noreply
  end

  def handle_event "create_new_context", %{ "context_type" => context_type }, socket do

    entity = case context_type do
      "Person" -> %Person{}
      _ -> %Context{}
    end

    socket
    |> assign(:edit_entity, entity)
    |> assign(:live_action, :new_context)
    |> assign(:edit_selected_context_type, context_type)
    |> return_noreply
  end

  # TODO check duplication with context_live/index
  def handle_event "delete_context", %{ "id" => id }, socket do
    context = Tracker.get_context!(id)
    {:ok, _} = Tracker.delete_context(context)

    state =
      socket.assigns
      |> IssuesMachine.set_context_properties(true)
      |> IssuesMachine.set_issue_properties

    socket
    |> assign(state)
    |> return_noreply
  end

  def handle_event "mouse_leave", _, socket do
    socket
    |> assign(:control_pressed, false)
    |> return_noreply
  end

  def handle_event "edit_context_description", _, socket do
    context = Tracker.get_context! socket.assigns.selected_context.id
    entity = case context.context_type do
      "Person" -> People.get_person! context.person.id
      _ -> context
    end
    socket
    |> assign(:edit_entity, entity)
    |> assign(:live_action, :describe_context)
    |> return_noreply
  end

  def handle_event "edit_context", id, socket do

    {id, ""} = Integer.parse id

    context = Tracker.get_context! id
    entity = case context.context_type do
      "Person" -> People.get_person! context.person.id
      _ -> context
    end

    socket
    |> assign(:edit_selected_context_type, context.context_type)
    |> assign(:edit_entity, entity)
    |> assign(:live_action, :edit_context)
    |> return_noreply
  end

  def handle_event "select_context", %{ "context" => context }, socket do
    state =
      socket.assigns
      |> IssuesMachine.select_context(context)
      |> IssuesMachine.set_issue_properties

    socket
    |> assign(state)
    |> do_query
  end

  def handle_event "link_context", %{ "title" => title }, socket do
    state =
      socket.assigns
      |> IssuesMachine.select_context(title)
      |> IssuesMachine.set_issue_properties

    socket
    |> assign(state)
    |> assign(:live_action, :link_context)
    |> return_noreply
  end

  def handle_event "reprioritize_context", %{ "title" => title }, socket do

    state =
      socket.assigns
      |> IssuesMachine.select_context!(title)
      |> IssuesMachine.set_issue_properties

    socket
    |> assign(state)
    |> push_event(:context_reprioritized, %{ id: state.selected_context.id })
    |> do_query
  end

  def handle_event "show_open_issues", params, socket do
    socket
    |> assign(:list_issues_done_instead_open, false)
    |> do_query
  end

  def handle_event "show_closed_issues", params, socket do
    socket
    |> assign(:list_issues_done_instead_open, true)
    |> do_query
  end

  def handle_event "select_issue", %{ "target" => id }, socket do
    selected_issue = Tracker.get_issue! id
    socket
    |> assign(:selected_issue, selected_issue)
    |> return_noreply
  end

  def handle_event "reprioritize_issue", %{ "id" => id }, socket do
    Tracker.get_issue!(id)
    |> Tracker.update_issue_updated_at
    selected_issue = Tracker.get_issue! id
    socket
    |> push_event(:issue_reprioritized, %{ id: id })
    |> assign(:selected_issue, selected_issue)
    |> do_query
  end

  def handle_event "toggle_context_important", %{ "target" => id }, socket do

    context = Tracker.get_context! id
    Tracker.update_context(context, %{ "important" => !context.important })

    socket
    |> assign(IssuesMachine.set_context_properties(to_state(socket)))
    |> push_event(:context_reprioritized, %{ id: id })
    |> do_query
  end

  def handle_event "toggle_issue_important", %{ "target" => id }, socket do

    selected_issue = Tracker.get_issue! id
    Tracker.update_issue2(selected_issue, %{ "important" => !selected_issue.important })

    socket
    |> assign(IssuesMachine.set_context_properties(to_state(socket)))
    |> assign(:selected_issue, selected_issue)
    |> push_event(:issue_reprioritized, %{ id: id })
    |> do_query
  end

  def handle_event "unarchive", %{ "target" => id }, socket do
    issue = Tracker.get_issue! id
    Tracker.update_issue2(issue, %{ "done" => false })

    socket
    |> assign(IssuesMachine.set_context_properties(to_state(socket)))
    |> assign(:list_issues_done_instead_open, false)
    |> do_query
  end

  def handle_event "archive", %{ "target" => id }, socket do
    socket
    |> assign(IssuesMachine.archive_issue(to_state(socket), id))
    |> do_query
  end

  defp do_query socket do
    do_query socket, false
  end
  defp do_query socket, suppress_return do
    socket = socket
    |> assign(IssuesMachine.do_query(socket.assigns |> Map.delete(:flash)))
    |> assign(:live_action, :index)

    if suppress_return do
      socket
    else
      socket |> return_noreply
    end
  end

  defp get_context_types params do
    if Map.has_key?(params, "context_types") do
      String.split(params["context_types"], "_")
    end
  end

  def should_show_issues_list_in_contexts_view nil, _ do
    false
  end

  defp should_show_contexts_view params do
    view = Enum.find(Application.fetch_env!(:cometoid, :context_types), fn ct -> ct.name == params["view"] end)
    ((!is_nil(params["alternative_view"]) && params["alternative_view"] == "true")
      or (!is_nil(view[:alternative_view] && view.alternative_view == true)))
  end

  # TODO only used in contexts view, so should be placed there
  def should_show_issues_list_in_contexts_view selected_context, list_issues_done_instead_open do
    issues = if list_issues_done_instead_open do
      Enum.filter selected_context.issues, &(&1.issue.done)
    else
      Enum.filter selected_context.issues, &(!&1.issue.done)
    end
    length(issues) > 0
  end

  defp to_state(socket), do: socket.assigns |> Map.delete(:flash)

  defp return_noreply(socket, flash_type, flash_value), do: {:noreply, socket |> put_flash(flash_type, flash_value)}

  defp return_noreply(socket), do: {:noreply, socket |> Map.delete(:flash) }
end
