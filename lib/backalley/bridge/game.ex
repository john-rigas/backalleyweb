defmodule Backalley.Bridge.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :name, :string
    field :num_players, :integer, default: 1
    field :start_hand, :integer
    field :end_hand, :integer
    field :player_seatmap, :map
    field :current_hand, :integer, default: 0
    field :scores, :map, default: %{1 => 0}

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [
      :name,
      :num_players,
      :start_hand,
      :end_hand,
      :player_seatmap,
      :current_hand,
      :scores
    ])
    |> validate_required([
      :name,
      :num_players,
      :start_hand,
      :end_hand,
      :player_seatmap,
      :current_hand,
      :scores
    ])
    |> validate_increasing_order(:start_hand, :end_hand)
  end

  defp validate_increasing_order(changeset, from, to, opts \\ []) do
    {_, from_value} = fetch_field(changeset, from)
    {_, to_value} = fetch_field(changeset, to)
    allow_equal = Keyword.get(opts, :allow_equal, true)

    if compare(from_value, to_value, allow_equal) do
      changeset
    else
      message = message(opts, "must be smaller then or equal to #{to}")
      add_error(changeset, from, message, to_field: to)
    end
  end

  defp compare(f, t, true), do: f <= t
  defp compare(f, t, false), do: f < t

  defp message(opts, field \\ :message, message) do
    Keyword.get(opts, field, message)
  end
end
