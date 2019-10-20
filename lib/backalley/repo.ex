defmodule Backalley.Repo do
  use Ecto.Repo,
    otp_app: :backalley,
    adapter: Ecto.Adapters.Postgres
end
