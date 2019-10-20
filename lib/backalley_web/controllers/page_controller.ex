defmodule BackalleyWeb.PageController do
  use BackalleyWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
