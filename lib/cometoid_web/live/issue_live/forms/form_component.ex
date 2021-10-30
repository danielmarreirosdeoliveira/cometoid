defmodule CometoidWeb.IssueLive.Modals.FormComponent do
  use CometoidWeb, :live_component

  alias Cometoid.Repo.Tracker

  @impl true
  def update(%{issue: issue} = assigns, socket) do
    changeset = Tracker.change_issue(issue)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  def handle_event("changes", %{ "issue" => issue_params }, socket) do
    {:noreply, socket |> assign(:has_event,
      (if issue_params["has_event"] == "true", do: true, else: false))}
  end

  def handle_event("save", %{"issue" => issue_params }, socket) do
    save_issue(socket, socket.assigns.action, issue_params)
  end

  defp save_issue(socket, :edit, issue_params) do

    case Tracker.update_issue(socket.assigns.issue, issue_params, []) do
      {:ok, issue} ->
        send self(), {:after_edit_form_save, issue}
        {:noreply, socket |> put_flash(:info, "Issue updated successfully")
        }
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
