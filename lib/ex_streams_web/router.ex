defmodule ExStreamsWeb.Router do
  use ExStreamsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExStreamsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExStreamsWeb do
    pipe_through :browser

    live_session :online do
      live "/", StreamLive, :index
      live "/b", BinanceLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExStreamsWeb do
  #   pipe_through :api
  # end
end
