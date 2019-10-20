defmodule Backalley.Repo.Migrations.UpdateGamesTTable do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :num_players, :integer
      add :start_hand, :integer
      add :end_hand, :integer
      add :player_seatmap, :map
    end
  end
end
