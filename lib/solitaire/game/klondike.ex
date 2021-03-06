defmodule Solitaire.Game.Klondike do
  alias Solitaire.Games
  alias Solitaire.Game.Klondike.Foundation

  @behaviour Solitaire.Games

  @black_suits ~w(spade club)a
  @red_suits ~w(diamond heart)a

  @deck Enum.flat_map(Games.ranks(), fn r -> Enum.map(Games.suits(), fn s -> {s, r} end) end)

  @impl Solitaire.Games
  def load_game(suit_count) do
    game =
      %{deck: rest_deck} =
      Enum.reduce(0..6, shuffle(), fn i, game ->
        Games.take_cards_to_col(game, i, i + 1, i, 12)
      end)

    Map.put(game, :deck, [[] | Games.split_deck_by(rest_deck, suit_count)])
  end

  @spec load_win_state(any) :: Solitaire.Games.t()
  def load_win_state(_params) do
    %Games{cols: []}
    |> Map.put(:deck, [[], [{:spade, :K}]])
    |> Map.put(
      :foundation,
      %{
        spade: %{rank: :D, from: nil, prev: nil, count: 0},
        diamond: %{rank: :K, from: nil, prev: nil, count: 0},
        heart: %{rank: :K, from: nil, prev: nil, count: 0},
        club: %{rank: :K, from: nil, prev: nil, count: 0}
      }
    )
  end

  @impl Games

  def move_to_foundation(game, attr, opts \\ [])

  def move_to_foundation(%{deck: deck, foundation: foundation} = game, :deck, opts) do
    if current = current(deck) do
      {from_suit, from_rank} = current
      foundation_rank = Foundation.fetch_rank_from_foundation(foundation, from_suit)

      if (foundation_rank == nil && from_rank == List.first(Games.ranks())) ||
           (Games.rank_index(from_rank) - 1 ==
              Games.rank_index(foundation_rank) &&
              Foundation.can_automove?(
                foundation,
                foundation_rank,
                from_suit,
                Keyword.get(opts, :auto, false)
              )) do
        move_from_deck_to_foundation(game, from_suit, ["deck"])
      else
        game
      end
    else
      game
    end
  end

  @impl Games

  def move_to_foundation(
        %{
          foundation: %{
            club: %{rank: :K},
            diamond: %{rank: :K},
            heart: %{rank: :K},
            spade: %{rank: :K}
          }
        } = game,
        _column,
        _opts
      ),
      do: game

  def move_to_foundation(%{cols: cols, foundation: foundation} = game, from_col_num, opts) do
    auto = Keyword.get(opts, :auto, false)

    %{cards: cards} = Enum.at(cols, from_col_num)

    if card = List.first(cards) do
      {from_suit, from_rank} = card
      foundation_rank = Foundation.fetch_rank_from_foundation(foundation, from_suit)

      if (foundation_rank == nil && from_rank == List.first(Games.ranks())) ||
           (Games.rank_index(from_rank) - 1 ==
              Games.rank_index(foundation_rank) &&
              Foundation.can_automove?(foundation, foundation_rank, from_suit, auto)) do
        Games.move_from_column_to_foundation(
          game,
          from_suit,
          from_col_num,
          1,
          ["column", from_col_num],
          Foundation
        )
      else
        game
      end
    else
      game
    end
  end

  defp move_from_deck_to_foundation(
         %{foundation: foundation, deck: deck, suit_count: suit_count} = game,
         suit,
         from
       ) do
    game
    |> Map.put(:foundation, Foundation.push(foundation, suit, from))
    |> Map.put(:deck, deck |> rest_deck |> split_deck_if_reached_the_end(suit_count))
  end

  @doc "Возвращает перемешанную колоду карт"
  @spec shuffle :: Solitaire.Games.t()
  def shuffle() do
    %{%Games{} | deck: Enum.shuffle(@deck)}
  end

  @doc """
    Берет следующую карту из колоды
  """
  @spec change(Game.t()) :: Games.t()
  @impl Solitaire.Games

  def change(%{deck: [[] | _rest] = deck, suit_count: suit_count} = game) do
    %{game | deck: split_deck_if_reached_the_end(deck, suit_count)}
  end

  def change(%{deck: [h | rest]} = game) do
    %{game | deck: rest ++ [h]}
  end

  defp split_deck_if_reached_the_end([[] | rest], suit_count) do
    (rest |> List.flatten() |> Games.split_deck_by(suit_count)) ++ [[]]
  end

  defp split_deck_if_reached_the_end(deck, _suit_count), do: deck

  def move_from_foundation(
        %{
          foundation: %{
            club: %{rank: :K},
            diamond: %{rank: :K},
            heart: %{rank: :K},
            spade: %{rank: :K}
          }
        } = game,
        _suit,
        _to_col_num
      ),
      do: game

  def move_from_foundation(game, suit, to_col_num) when is_binary(suit),
    do: move_from_foundation(game, String.to_existing_atom(suit), to_col_num)

  def move_from_foundation(
        %{cols: cols, foundation: foundation} = game,
        suit,
        to_col_num
      ) do
    from_rank = Foundation.fetch_rank_from_foundation(foundation, suit)

    to_column = %{cards: [to | _] = cards} = Enum.at(cols, to_col_num)

    if from_rank && can_move?(to, {suit, from_rank}) do
      game
      |> Map.put(:foundation, Foundation.pop(foundation, suit))
      |> Games.update_cols(to_col_num, %{to_column | cards: [{suit, from_rank} | cards]})
    else
      game
    end
  end

  @impl Games
  @spec move_from_column(%{cols: any}, {integer, integer}, integer) ::
          {:error, Games.t()} | {:ok, Games.t()}
  def move_from_column(game, from_col_num, to_col_num) do
    Games.move_cards_from_column(game, from_col_num, to_col_num, &can_move?(&1, &2))
  end

  defp rest_deck([[], [_h | t] | rest]) do
    [t | rest] ++ [[]]
  end

  defp rest_deck([[_current | []] | rest_deck]) do
    last_cards = List.last(rest_deck)
    [last_cards | Enum.take(rest_deck, length(rest_deck) - 1)]
  end

  defp rest_deck([[_current | rest] | rest_deck]) do
    [rest | rest_deck]
  end

  defp current(deck) do
    deck |> List.first() |> List.first()
  end

  @impl Games
  @spec move_from_deck(%{cols: any, deck: [...], suit_count: integer()}, integer) ::
          {:ok, Games.t()} | {:error, Games.t()}
  def move_from_deck(
        %{deck: deck, cols: cols, suit_count: suit_count} = game,
        column
      ) do
    if deck_non_empty?(deck) do
      current = current(deck)

      deck = deck |> rest_deck() |> split_deck_if_reached_the_end(suit_count)

      col = %{cards: cards} = Enum.at(cols, column)
      upper_card = List.first(cards)

      if can_move?(upper_card, current) do
        cards = [current | cards]

        {:ok,
         game
         |> Games.update_cols(column, %{col | cards: cards})
         |> Map.put(:deck, deck)}
      else
        {:error, game}
      end
    else
      {:error, game}
    end
  end

  defp deck_non_empty?(deck) do
    List.flatten(deck) != []
  end

  @impl Games
  def can_move?(to, from) when is_list(from) do
    can_move?(to, List.last(from))
  end

  def can_move?(nil, {_, rank}) do
    rank == List.last(Games.ranks())
  end

  def can_move?(nil, _from_card), do: false

  def can_move?(_to_card, nil), do: false

  def can_move?({suit, _}, {suit, _}), do: false

  def can_move?({_, rank}, {_, rank}), do: false

  # to, from
  def can_move?({to_col_suit, to_col_rank}, {from_suit, from_rank}) do
    with false <- from_rank == List.first(Games.ranks()),
         1 <- Games.rank_index(to_col_rank) - Games.rank_index(from_rank),
         true <- suits_of_different_color?(from_suit, to_col_suit) do
      true
    else
      _result -> false
    end
  end

  defp suits_of_different_color?(suit, suit), do: false

  defp suits_of_different_color?(suit1, suit2) do
    if suit1 in @black_suits do
      suit2 in @red_suits
    else
      suit2 in @black_suits
    end
  end
end
