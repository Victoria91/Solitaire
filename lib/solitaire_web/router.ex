defmodule SolitaireWeb.Router do
  use SolitaireWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug(Phoenix.LiveView.Flash)
    # plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SolitaireWeb do
    pipe_through :browser

    get "/", PageController, :index
    live "/game", GameLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", SolitaireWeb do
  #   pipe_through :api
  # end
end
