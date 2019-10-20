defmodule BackalleyWeb.GameController do
  use BackalleyWeb, :controller

  alias Backalley.Bridge
  alias Backalley.Bridge.Game

  @topic inspect(__MODULE__)

  def index(conn, _params) do
    games = Bridge.list_games()
    render(conn, "index.html", games: games)
  end

  def new(conn, _params) do
    changeset = Bridge.change_game(%Game{})
    render(conn, "new.html", changeset: changeset, game_status: :new)
  end

  def create(conn, %{"game" => game_params}) do
    %{"first_player" => player} = game_params

    conn = put_session(conn, :player, 1)

    case Bridge.create_game(Map.put(game_params, "player_seatmap", %{1 => player})) do
      {:ok, game} ->
        conn
        # |> put_flash(:info, "Game created successfully.")
        |> redirect(to: Routes.game_path(conn, :show, game))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset, game_status: :new)
    end
  end

  def show(conn, %{"id" => id}) do
    game = Bridge.get_game!(id)
    render(conn, "show.html", game: game, player: get_session(conn, :player))
  end

  def edit(conn, %{"id" => id}) do
    game = Bridge.get_game!(id)
    changeset = Bridge.change_game(game)
    player_list = Enum.map(game.player_seatmap, fn {_k, v} -> v end)

    name_options =
      ["chris", "andrew", "david", "johnny", "doc", "jenkins"]
      |> Enum.filter(fn x -> !Enum.member?(player_list, x) end)

    render(conn, "edit.html",
      game: game,
      changeset: changeset,
      game_status: :exists,
      name_options: name_options
    )
  end

  def update(conn, %{"id" => id, "game" => %{"new_player" => player}}) do
    game = Bridge.get_game!(id)

    %Game{player_seatmap: seatmap, scores: scores} = game
    next_seat = map_size(seatmap) + 1

    conn = put_session(conn, :player, next_seat)

    case Bridge.update_game(game, %{
           "player_seatmap" => Map.put(seatmap, Integer.to_string(next_seat), player),
           "scores" => Map.put(scores, Integer.to_string(next_seat), 0),
           "num_players" => next_seat
         }) do
      {:ok, game} ->
        Phoenix.PubSub.broadcast(Backalley.PubSub, @topic, {"player_joined", game})

        conn
        # |> put_flash(:info, "Game updated successfully.")
        |> redirect(to: Routes.game_path(conn, :show, game))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", game: game, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    game = Bridge.get_game!(id)
    {:ok, _game} = Bridge.delete_game(game)

    conn
    |> put_flash(:info, "Game deleted successfully.")
    |> redirect(to: Routes.game_path(conn, :index))
  end
end
