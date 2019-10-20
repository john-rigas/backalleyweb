defmodule Backalley.LiveGame do
  use Phoenix.LiveView
  alias Backalley.Bridge
  alias BackalleyWeb.LivegameView

  @topic inspect(__MODULE__)

  def mount(session, socket) do
    Phoenix.PubSub.subscribe(Backalley.PubSub, @topic)
    Phoenix.PubSub.subscribe(Backalley.PubSub, "BackalleyWeb.GameController")

    restore =
      cond do
        session.game.current_hand == 0 -> false
        true -> true
      end

    {:ok, assign(socket, %{game: session.game, player: session.player, restore: restore})}
  end

  def render(assigns) do
    LivegameView.render("livegame.html", assigns)
  end

  def handle_event("start", %{}, socket) do
    {:ok, game} = Bridge.start_game(socket.assigns.game)
    {cardmap, trump} = Bridge.deal(game)
    boardmap = Bridge.create_empty_bridgemap(game)
    bidmap = Bridge.create_empty_bridgemap(game)
    trickswonmap = Bridge.create_zeros_bridgemap(game)

    Phoenix.PubSub.broadcast(
      Backalley.PubSub,
      @topic,
      {"start", game, trump, cardmap, 2, boardmap, 2, [], [], socket.assigns.game.start_hand,
       bidmap, trickswonmap, 1, 2}
    )

    {:noreply,
     assign(socket, %{
       game: game,
       trump: trump,
       cardmap: cardmap,
       turn: 2,
       boardmap: boardmap,
       starting_player: 2,
       hand_history: [],
       trick_history: [],
       current_hand: socket.assigns.game.start_hand,
       bidmap: bidmap,
       dealer: 1,
       previous_trick_winner: 2,
       trickswonmap: trickswonmap
     })}
  end

  def handle_event("throw", %{"card" => card, "player" => playerid}, socket) do
    new_previous_trick_winner =
      if length(socket.assigns.trick_history) == socket.assigns.game.num_players - 1 do
        Bridge.calc_trick_winner(
          socket.assigns.starting_player,
          [card | socket.assigns.trick_history],
          socket.assigns.trump
        )
      else
        socket.assigns.previous_trick_winner
      end

    {_old_val, new_trickswonmap} =
      if length(socket.assigns.trick_history) == socket.assigns.game.num_players - 1 do
        Map.get_and_update(socket.assigns.trickswonmap, new_previous_trick_winner, fn x ->
          {x, x + 1}
        end)
      else
        {nil, socket.assigns.trickswonmap}
      end

    {new_hand_history, new_game} =
      if length(socket.assigns.hand_history) ==
           socket.assigns.game.num_players * socket.assigns.game.current_hand - 1 do
        new_scores =
          Bridge.update_scores(
            socket.assigns.game.scores,
            socket.assigns.bidmap,
            new_trickswonmap
          )

        {:ok, new_game} =
          Bridge.update_game(socket.assigns.game, %{
            "current_hand" => socket.assigns.game.current_hand + 1,
            "scores" => new_scores
          })

        Phoenix.PubSub.broadcast(Backalley.PubSub, @topic, {"new_hand", new_game})
        {[], new_game}
      else
        {[card | socket.assigns.hand_history], socket.assigns.game}
      end

    {_old_val, new_trickswonmap} =
      if new_hand_history == [] do
        {nil, Bridge.create_zeros_bridgemap(socket.assigns.game)}
      else
        {nil, new_trickswonmap}
      end

    new_trick_history =
      if length(socket.assigns.trick_history) == socket.assigns.game.num_players - 1 do
        []
      else
        [card | socket.assigns.trick_history]
      end

    new_boardmap =
      if new_trick_history == [] do
        Bridge.create_empty_bridgemap(socket.assigns.game)
      else
        Map.put(socket.assigns.boardmap, String.to_integer(playerid), card)
      end

    new_dealer =
      if new_hand_history == [] do
        case rem(socket.assigns.dealer + 1, socket.assigns.game.num_players) do
          0 -> socket.assigns.game.num_players
          other -> other
        end
      else
        socket.assigns.dealer
      end

    new_starting_player =
      cond do
        new_hand_history == [] ->
          case rem(new_dealer + 1, socket.assigns.game.num_players) do
            0 -> socket.assigns.game.num_players
            other -> other
          end

        new_trick_history == [] ->
          new_previous_trick_winner

        true ->
          socket.assigns.starting_player
      end

    new_turn =
      if new_trick_history == [] do
        new_starting_player
      else
        case rem(socket.assigns.turn + 1, socket.assigns.game.num_players) do
          0 -> socket.assigns.game.num_players
          other -> other
        end
      end

    new_bidmap =
      if new_hand_history == [] do
        Bridge.create_empty_bridgemap(socket.assigns.game)
      else
        socket.assigns.bidmap
      end

    {_old_cardmap, new_cardmap, new_trump} =
      if new_hand_history == [] do
        {cardmap, trump} = Bridge.deal(new_game)
        {nil, cardmap, trump}
      else
        {old_cardmap, cardmap} =
          Map.get_and_update(socket.assigns.cardmap, String.to_integer(playerid), fn x ->
            {x, List.delete(x, card)}
          end)

        {old_cardmap, cardmap, socket.assigns.trump}
      end

    Phoenix.PubSub.broadcast(
      Backalley.PubSub,
      @topic,
      {"throw", new_hand_history, new_trick_history, new_boardmap, new_cardmap, new_turn,
       new_trump, new_previous_trick_winner, new_dealer, new_starting_player, new_trickswonmap,
       new_bidmap}
    )

    {:noreply,
     assign(socket, %{
       hand_history: new_hand_history,
       trick_history: new_trick_history,
       boardmap: new_boardmap,
       cardmap: new_cardmap,
       turn: new_turn,
       trump: new_trump,
       bidmap: new_bidmap,
       dealer: new_dealer,
       starting_player: new_starting_player,
       trickswonmap: new_trickswonmap
     })}
  end

  def handle_event("bid" <> playerid, %{"bidamount" => bidamount}, socket) do
    new_bidmap = Map.put(socket.assigns.bidmap, String.to_integer(playerid), bidamount)

    new_turn =
      case rem(socket.assigns.turn + 1, socket.assigns.game.num_players) do
        0 -> socket.assigns.game.num_players
        other -> other
      end

    Phoenix.PubSub.broadcast(Backalley.PubSub, @topic, {"bid", new_bidmap, new_turn})

    {:noreply, assign(socket, %{bidmap: new_bidmap, turn: new_turn})}
  end

  def handle_event("restore", %{}, socket) do
    Phoenix.PubSub.broadcast(Backalley.PubSub, @topic, {"needs_restore", socket.assigns.player})
    {:noreply, socket}
  end

  def handle_info(
        {"start", game, trump, cardmap, turn, boardmap, starting_player, hand_history,
         trick_history, current_hand, bidmap, trickswonmap, dealer, previous_trick_winner},
        socket
      ) do
    {:noreply,
     assign(socket, %{
       game: game,
       trump: trump,
       cardmap: cardmap,
       turn: turn,
       boardmap: boardmap,
       starting_player: starting_player,
       hand_history: hand_history,
       trick_history: trick_history,
       current_hand: current_hand,
       bidmap: bidmap,
       trickswonmap: trickswonmap,
       previous_trick_winner: previous_trick_winner,
       dealer: dealer
     })}
  end

  def handle_info(
        {"throw", hand_history, trick_history, boardmap, cardmap, turn, trump,
         previous_trick_winner, dealer, starting_player, trickswonmap, bidmap},
        socket
      ) do
    {:noreply,
     assign(socket, %{
       hand_history: hand_history,
       trick_history: trick_history,
       boardmap: boardmap,
       cardmap: cardmap,
       turn: turn,
       trump: trump,
       previous_trick_winner: previous_trick_winner,
       dealer: dealer,
       starting_player: starting_player,
       trickswonmap: trickswonmap,
       bidmap: bidmap
     })}
  end

  def handle_info({"bid", bidmap, turn}, socket) do
    {:noreply, assign(socket, %{bidmap: bidmap, turn: turn})}
  end

  def handle_info({"new_hand", game}, socket) do
    {:noreply, assign(socket, %{game: game})}
  end

  def handle_info({"player_joined", game}, socket) do
    {:noreply, assign(socket, %{game: game})}
  end

  def handle_info({"needs_restore", playerid}, socket) do
    unless socket.assigns.player == playerid do
      Phoenix.PubSub.broadcast(
        Backalley.PubSub,
        @topic,
        {"complete_restore", socket.assigns.game, socket.assigns.trump, socket.assigns.cardmap,
         socket.assigns.turn, socket.assigns.boardmap, socket.assigns.starting_player,
         socket.assigns.hand_history, socket.assigns.trick_history, socket.assigns.current_hand,
         socket.assigns.bidmap, socket.assigns.dealer, socket.assigns.previous_trick_winner,
         socket.assigns.trickswonmap}
      )
    end

    {:noreply, socket}
  end

  def handle_info(
        {"complete_restore", game, trump, cardmap, turn, boardmap, starting_player, hand_history,
         trick_history, current_hand, bidmap, dealer, previous_trick_winner, trickswonmap},
        socket
      ) do
    IO.inspect("YAO")

    {:noreply,
     assign(socket, %{
       game: game,
       trump: trump,
       cardmap: cardmap,
       turn: turn,
       boardmap: boardmap,
       starting_player: starting_player,
       hand_history: hand_history,
       trick_history: trick_history,
       current_hand: current_hand,
       bidmap: bidmap,
       dealer: dealer,
       previous_trick_winner: previous_trick_winner,
       trickswonmap: trickswonmap,
       restore: false
     })}
  end
end
