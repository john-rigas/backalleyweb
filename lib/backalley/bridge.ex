defmodule Backalley.Bridge do
  @moduledoc """
  The Bridge context.
  """

  import Ecto.Query, warn: false
  alias Backalley.Repo

  alias Backalley.Bridge.Game

  @rankings ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
  @suits ["H", "C", "D", "S"]
  @rankmap %{
    "2" => 0,
    "3" => 1,
    "4" => 2,
    "5" => 3,
    "6" => 4,
    "7" => 5,
    "8" => 6,
    "9" => 7,
    "T" => 8,
    "J" => 9,
    "Q" => 10,
    "K" => 11,
    "A" => 12
  }

  defstruct trump: nil, cardmap: %{}

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id), do: Repo.get!(Game, id)

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{source: %Game{}}

  """
  def change_game(%Game{} = game) do
    Game.changeset(game, %{})
  end

  def start_game(%Game{} = game) do
    game
    |> Game.changeset(%{current_hand: game.start_hand})
    |> Repo.update()
  end

  def deal(%Game{player_seatmap: seatmap, current_hand: num_cards}) do
    {cardmap, deck} =
      Enum.into(1..map_size(seatmap), %{}, fn x -> {x, []} end)
      |> deal_hand(build_deck(), num_cards, map_size(seatmap))

    {_deck, trump} = draw(deck)
    {cardmap, trump}
  end

  def deal_hand(cardmap, deck, num_cards, players_left) do
    cond do
      players_left == 0 ->
        {cardmap, deck}

      players_left > 0 ->
        {deck, hand} = deal_card(deck, [], num_cards, players_left)
        cardmap = Map.put(cardmap, players_left, hand)
        deal_hand(cardmap, deck, num_cards, players_left - 1)
    end
  end

  def deal_card(deck, hand, num_cards, player_id) do
    cond do
      num_cards == 0 ->
        {deck, hand}

      num_cards > 0 ->
        {deck, card} = draw(deck)
        hand = [card | hand]
        deal_card(deck, hand, num_cards - 1, player_id)
    end
  end

  def build_deck() do
    for suit <- @suits do
      for rank <- @rankings do
        rank <> suit
      end
    end
    |> Enum.reduce(fn one, two -> one ++ two end)
  end

  def draw(deck) do
    :random.seed(:erlang.now())
    [card] = Enum.take_random(deck, 1)
    deck = List.delete(deck, card)
    {deck, card}
  end

  def create_empty_bridgemap(%Game{player_seatmap: seatmap}) do
    Enum.into(1..map_size(seatmap), %{}, fn x -> {x, nil} end)
  end

  def create_zeros_bridgemap(%Game{player_seatmap: seatmap}) do
    Enum.into(1..map_size(seatmap), %{}, fn x -> {x, 0} end)
  end

  def calc_trick_winner(starting_player, trick_history, trump) do
    {_winning_card, idx} =
      trick_history
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce({List.last(trick_history), starting_player}, fn x, acc ->
        beats(x, acc, trump)
      end)

    case rem(starting_player + idx, length(trick_history)) do
      0 -> length(trick_history)
      other -> other
    end
  end

  defp beats(
         {<<new_rank::bytes-size(1)>> <> new_suit, _new_idx} = new,
         {<<inc_rank::bytes-size(1)>> <> inc_suit, _inc_idx} = inc,
         <<_trump_rank::bytes-size(1)>> <> trump_suit
       ) do
    cond do
      new_suit == trump_suit and inc_suit != trump_suit ->
        new

      new_suit != inc_suit ->
        inc

      Map.get(@rankmap, new_rank) < Map.get(@rankmap, inc_rank) ->
        inc

      true ->
        new
    end
  end

  def update_scores(scores, bidmap, trickswonmap) do
    scores
    |> Enum.map(fn {k, v} ->
      {k,
       v +
         calc_score(
           String.to_integer(Map.get(bidmap, String.to_integer(k))),
           Map.get(trickswonmap, String.to_integer(k))
         )}
    end)
    |> Enum.into(%{})
  end

  defp calc_score(bid, trickswon) do
    cond do
      bid == trickswon ->
        bid + 10

      true ->
        trickswon
    end
  end

  def can_throw_card(
        card,
        trump,
        playerid,
        starting_player,
        player_cards,
        trick_history,
        hand_history
      ) do
    cond do
      check_if_card_is_trump(card, trump) and not check_if_trump_thrown(trump, hand_history) and
        check_if_holding_leading_suit(trick_history, player_cards) and
          !check_if_all_cards_are_trumps(player_cards, trump) ->
        {false, "Trump not thrown"}

      starting_player == playerid ->
        {true, nil}

      !check_if_card_is_leading_suit(card, trick_history) and
          check_if_holding_leading_suit(trick_history, player_cards) ->
        {false, "You must throw leading suit"}

      true ->
        {true, nil}
    end
  end

  def check_if_trump_thrown(<<_trump_rank::bytes-size(1)>> <> trump_suit, hand_history) do
    case hand_history do
      [] ->
        false

      history ->
        history
        |> Enum.map(fn <<_card_rank::bytes-size(1)>> <> card_suit -> card_suit end)
        |> Enum.member?(trump_suit)
    end
  end

  def check_if_holding_leading_suit(trick_history, player_cards) do
    player_cards
    |> Enum.reduce(false, fn x, acc -> acc or check_if_card_is_leading_suit(x, trick_history) end)
  end

  def check_if_card_is_leading_suit(<<_card_rank::bytes-size(1)>> <> card_suit, trick_history) do
    case trick_history do
      [] ->
        true

      history ->
        [<<_leading_rank_rank::bytes-size(1)>> <> leading_suit | _tail] = Enum.reverse(history)
        leading_suit == card_suit
    end
  end

  def check_if_all_cards_are_trumps(player_cards, trump) do
    player_cards
    |> Enum.reduce(true, fn x, acc -> acc and check_if_card_is_trump(x, trump) end)
  end

  def check_if_card_is_trump(
        <<_card_rank::bytes-size(1)>> <> card_suit,
        <<_trump_rank::bytes-size(1)>> <> trump_suit
      ) do
    trump_suit == card_suit
  end

  def get_possible_bids(current_hand, bidmap) do
    total_bids =
      bidmap
      |> Map.values()
      |> Enum.filter(fn x -> x != nil end)
      |> Enum.map(fn x -> String.to_integer(x) end)
      |> Enum.sum()

    illegal_bid = current_hand - total_bids

    0..current_hand
    |> Enum.filter(fn x -> x != illegal_bid end)
  end
end
