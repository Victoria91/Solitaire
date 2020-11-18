defmodule SolitaireWeb.GameChannel do
  use SolitaireWeb, :channel

  alias Solitaire.Game.Server, as: GameServer
  alias Solitaire.Game.Supervisor, as: GameSupervisor

  def join(_topic, _params, socket) do
    token = 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64()

    GameSupervisor.start_game(%{token: token})

    state = GameServer.state(token)

    Phoenix.PubSub.subscribe(Solitaire.PubSub, "game:#{token}")

    {:ok, fetch_game_state(state), assign(socket, :token, token)}
  end

  def handle_info({:tick, game}, socket) do
    broadcast!(socket, "update_game", fetch_game_state(game))

    {:noreply, socket}
  end

  def handle_info(:win, socket) do
    broadcast!(socket, "win", %{})
    {:noreply, socket}
  end

  def fetch_game_state(%{
        foundation: foundation,
        cols: cols,
        deck: deck,
        deck_length: deck_length
      }) do
    %{
      columns:
        Enum.map(cols, fn %{cards: cards} = map ->
          %{map | cards: convert_keyword_to_list(cards)}
        end),
      deck_length: deck_length,
      foundation: convert_to_string(foundation),
      deck: deck |> Enum.map(&convert_keyword_to_list/1) |> List.first()
    }
  end

  defp convert_to_string(map) do
    Map.new(map, fn
      {k, %{rank: rank, prev: prev} = foundation} ->
        {k,
         foundation
         |> Map.put(:rank, convert_rank_to_string(rank))
         |> Map.put(:prev, convert_rank_to_string(prev))}
    end)
  end

  defp convert_rank_to_string(nil), do: nil

  defp convert_rank_to_string(rank) when is_atom(rank) do
    Atom.to_string(rank)
  end

  defp convert_rank_to_string(rank) when is_integer(rank) do
    Integer.to_string(rank)
  end

  defp convert_keyword_to_list(kw) do
    Enum.map(kw, fn
      [] -> []
      {k, v} -> [k, v]
    end)
  end

  def handle_in("start_new_game", _params, %{assigns: %{token: token}} = socket) do
    GameSupervisor.restart_game(token, %{})

    state = GameServer.state(token)

    {:reply, {:ok, fetch_game_state(state)}, socket}
  end

  def handle_in(
        "move_from_foundation",
        %{"suit" => suit, "to_column" => to_column},
        %{assigns: %{token: token}} = socket
      ) do
    new_state = GameServer.move_from_foundation(token, suit, to_column)
    {:reply, {:ok, fetch_game_state(new_state)}, socket}
  end

  def handle_in(
        "move_from_column",
        %{
          "from_card_index" => card_index,
          "from_column" => from_column,
          "to_column" => to_column
        },
        %{assigns: %{token: token}} = socket
      ) do
    case GameServer.move_from_column(token, {from_column, card_index}, to_column) do
      {:ok, new_state} ->
        {:reply, {:ok, fetch_game_state(new_state)}, socket}

      {:error, old_state} ->
        {:reply, {:error, fetch_game_state(old_state)}, socket}
    end
  end

  def handle_in(
        "move_to_foundation_from_column",
        %{
          "from_column" => from_column
        },
        %{assigns: %{token: token}} = socket
      ) do
    new_state = GameServer.move_to_foundation(token, from_column)
    {:reply, {:ok, fetch_game_state(new_state)}, socket}
  end

  def handle_in(
        "move_to_foundation_from_deck",
        _payload,
        %{assigns: %{token: token}} = socket
      ) do
    new_state = GameServer.move_to_foundation(token, :deck)
    {:reply, {:ok, fetch_game_state(new_state)}, socket}
  end

  def handle_in("change", _params, %{assigns: %{token: token}} = socket) do
    new_state = GameServer.change(token)
    {:reply, {:ok, fetch_game_state(new_state)}, socket}
  end

  def handle_in(
        "move_from_deck",
        %{"to_column" => to_column},
        %{assigns: %{token: token}} = socket
      ) do
    case GameServer.move_from_deck(token, to_column) do
      {:ok, new_state} ->
        {:reply, {:ok, fetch_game_state(new_state)}, socket}

      {:error, _} ->
        {:reply, :error, socket}
    end
  end
end
