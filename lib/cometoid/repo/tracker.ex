defmodule Cometoid.Repo.Tracker do
  @moduledoc """
  The Tracker context.
  """

  import Ecto.Query, warn: false
  alias Cometoid.Repo
  alias Cometoid.Model.Tracker.Relation
  alias Cometoid.Model.Tracker.Context
  alias Cometoid.Model.Calendar
  alias Cometoid.Model.Tracker.Issue

  def list_contexts view do
    Context
    |> where([c], c.view == ^view)
    |> order_by([c], [{:desc, c.important}, {:desc, c.updated_at}])
    |> Repo.all
    |> Repo.preload(:person)
    |> Repo.preload(:text)
    |> Repo.preload(:secondary_contexts)
  end

  def list_contexts do
    Repo.all(from c in Context,
      order_by: [desc: :important, desc: :updated_at])
    |> Repo.preload(issues: :issue)
    |> Repo.preload(person: :birthday)
    |> Repo.preload(:text)
    |> Repo.preload(:secondary_contexts)
  end

  def get_context! id do
    Repo.get!(Context, id)
    |> Repo.preload(person: :birthday)
    |> Repo.preload(:text)
    |> Repo.preload(issues: :issue)
    |> Repo.preload(:secondary_contexts)
  end

  def create_context attrs do
    %Context{}
    |> Context.changeset(attrs)
    |> Repo.insert()
  end

  def update_context %Context{} = context, attrs do
    context
    |> Context.changeset(attrs)
    |> Repo.update()
  end

  def update_context_updated_at context do
    context
    |> Context.changeset(%{})
    |> Repo.update(force: true)
  end

  def link_contexts primary_context, secondary_contexts_ids do
    secondary_contexts = get_contexts_by_ids secondary_contexts_ids
    result =
      primary_context
      |> Context.link_contexts_changeset(%{ "secondary_contexts" => secondary_contexts})
      |> Repo.update()

    Enum.map secondary_contexts, fn secondary_context ->
      secondary_context = Repo.preload secondary_context, :secondary_contexts
      secondary_contexts_reverse_ids = Enum.map secondary_context.secondary_contexts, &(&1.id)
      unless primary_context.id in secondary_contexts_reverse_ids do
        secondary_context
        |> Context.link_contexts_changeset(
          %{ "secondary_contexts" =>
            [primary_context|secondary_context.secondary_contexts]
          }
        )
        |> Repo.update()
      end
    end

    result
  end

  defp get_contexts_by_ids ids do
    Context
    |> where([c], c.id in ^ids)
    |> Repo.all
  end

  def delete_context %Context{} = context do

    issue_ids = Enum.map(context.issues, &(&1.id))
    Repo.delete(context)
    Enum.map(issue_ids, fn issue_id ->
      issue = get_issue!(issue_id)
      if issue.contexts == [], do: Repo.delete(issue)
    end)
    {:ok, 1}
  end

  def change_context %Context{} = context, attrs \\ %{} do
    Context.changeset(context, attrs)
  end

  defmodule Query do
    defstruct selected_context: nil, # required
      list_issues_done_instead_open: false
  end

  def list_issues query do
    query =
      Issue
      |> join(:left, [i], c in assoc(i, :contexts))
      |> join(:left, [i, c], cc in assoc(c, :context))
      |> where_type(query)
      |> order_by([i, _c, _cc, _it], [{:desc, i.important}, {:desc, i.updated_at}])

      Repo.all(query)
      |> Repo.preload(contexts: :context)
      |> Repo.preload(:event)
  end

  defp where_type(query, %{
      selected_context: selected_context,
      list_issues_done_instead_open: list_issues_done_instead_open
    }) do
    query
    |> where([i, _c, cc], cc.id == ^selected_context.id and i.done == ^list_issues_done_instead_open)
  end

  def get_issue! id do
    Repo.get!(Issue, id)
    |> Repo.preload(contexts: :context)
    |> Repo.preload(:event)
  end

  def create_issue title, contexts do
    {:ok, issue} = Repo.insert(%Issue{
      title: title,
      contexts: Enum.map(contexts, &(%{ context: &1 }))
    })
    {:ok, Repo.preload(issue, :event)}
  end

  def update_issue_relations issue, selected_contexts, contexts do

    context_from =  fn id -> Enum.find contexts, &(&1.id == id) end # TODO use get_context! instead
    ctxs = Enum.map(selected_contexts, context_from)
      |> Enum.map(fn ctx -> %{ context: ctx } end)

    issue
    |> Issue.relations_changeset(%{ "contexts" => ctxs })
    |> Repo.update
  end

  def update_issue %Issue{} = issue, attrs, contexts do

    attrs = unless is_nil(attrs["contexts"]) do
      context_from = fn title -> Enum.find contexts, &(&1.title == title) end
      put_in(attrs["contexts"], Enum.map(attrs["contexts"], context_from))
    else
      attrs
    end

    if not is_nil(issue.event) and is_nil(attrs["event"]) do
      Issue.delete_event_changeset(issue, attrs)
    else
      Issue.changeset(issue, attrs)
    end
    |> Repo.update
  end

  def update_issue_description issue, attrs do
    issue
    |> Issue.description_changeset(attrs)
    |> Repo.update
  end

  def update_issue2(issue, attrs) do
    changeset = Issue.changeset(issue, attrs)
    |> Repo.update
  end

  def update_issue_updated_at(issue) do
    issue
    |> Issue.changeset(%{})
    |> Repo.update(force: true)
  end

  def delete_issue(%Issue{} = issue) do
    Repo.delete(issue)
  end

  def change_issue(%Issue{} = issue, attrs \\ %{}) do
    Issue.changeset(issue, attrs)
  end
end
