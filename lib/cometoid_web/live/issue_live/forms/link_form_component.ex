defmodule CometoidWeb.IssueLive.LinkFormComponent do
  use CometoidWeb, :live_component

  alias Cometoid.Repo.Tracker

  def handle_event("save", %{"abc" => abc }, socket) do

    selected_contexts =
      abc
      |> Enum.filter(&filter_true/1)
      |> Enum.map(&to_key/1)

    issue = socket.assigns.issue

    issue_params = %{ "contexts" => selected_contexts }

    relations = Tracker.list_relations
    relations = Enum.filter(relations, fn rel -> rel.context.context_type in (socket.assigns.context_types ++ ["Person"]) end)

    contexts = Tracker.list_contexts
    contexts = Enum.filter(contexts, fn context -> context.context_type in (socket.assigns.context_types ++ ["Person"]) end)

    if length(selected_contexts) == 0 do
      {:noreply, socket}
    else
      case Tracker.update_issue_relations(issue, issue_params, relations, contexts) do
        {:ok, issue} ->
          send self(), {:after_edit_form_save, issue}
          {:noreply,
           socket |> put_flash(:info, "Issue updated successfully")
          }
        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    end
  end

  def list_contexts context_type do

    results = Tracker.list_contexts context_type
    Enum.map results, fn r -> r.title end
  end

  def is_checked issue, context_title do
    context_titles = Enum.map issue.contexts, &(&1.context.title)
    not is_nil Enum.find context_titles, &(&1 == context_title)
  end

  defp filter_true({k, v}), do: v == "true"

  defp to_key({k, v}), do: String.replace(k, "ctx/", "")
end
