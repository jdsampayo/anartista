defmodule AnartistaWeb.ContactLive do
  use AnartistaWeb, :live_view
  alias Anartista.Contact
  alias Anartista.Contact.Message

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form, to_form(Contact.change_message(%Message{})))
     |> assign(:submitted, false),
     layout: {AnartistaWeb.Layouts, :empty}
    }
  end

  @impl true
  def handle_event("save", %{"message" => message_params}, socket) do
    case Contact.create_message(message_params) do
      {:ok, _message} ->
        {:noreply,
         socket
         |> assign(:form, to_form(Contact.change_message(%Message{})))
         |> assign(:submitted, true)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("new_message", _, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(Contact.change_message(%Message{})))
     |> assign(:submitted, false)
    }
  end
end
