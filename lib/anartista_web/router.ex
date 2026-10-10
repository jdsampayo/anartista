defmodule AnartistaWeb.Router do
  use AnartistaWeb, :router

  import AnartistaWeb.AdminAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AnartistaWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :admin_session do
    plug(:fetch_current_user)
    plug(:prevent_caching)
  end

  pipeline :admin do
    plug(:require_authenticated_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", AnartistaWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    get("/about", PageController, :about)
    get("/obra", PageController, :obra)
    get("/exhibitions", PageController, :exhibitions)
    get("/writing", PageController, :writing)
    get("/contact", PageController, :contact)
    get("/store", PageController, :shop)
  end

  scope "/admin", AnartistaWeb.Admin do
    pipe_through([:browser, :admin_session])

    get("/login", SessionController, :new)
    post("/login", SessionController, :create)
    delete("/logout", SessionController, :delete)
  end

  scope "/admin", AnartistaWeb.Admin do
    pipe_through([:browser, :admin_session, :admin])

    live_session :admin,
      on_mount: [{AnartistaWeb.AdminAuth, :require_authenticated}] do
      live("/", DashboardLive, :index)
      live("/store", StoreLive, :index)
      live("/messages", MessagesLive, :index)
      live("/exhibitions", ExhibitionsLive, :index)
      live("/obra", ArtworkLive, :index)
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", AnartistaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:anartista, :dev_routes) do
    # Production admin routes use session authentication; these tools are development-only.
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: AnartistaWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
