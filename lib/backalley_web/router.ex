defmodule BackalleyWeb.Router do
  use BackalleyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Phoenix.LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BackalleyWeb do
    pipe_through :browser

    get "/", PageController, :index

    resources "/games", GameController
  end

  # Other scopes may use custom stacks.
  # scope "/api", BackalleyWeb do
  #   pipe_through :api
  # end
end
