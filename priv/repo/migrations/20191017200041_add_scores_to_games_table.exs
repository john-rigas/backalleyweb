defmodule Backalley.Repo.Migrations.AddScoresToGamesTable do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :scores, :map, default: %{1 => 0}
      add :current_hand, :integer, default: 0
    end
  end
end
