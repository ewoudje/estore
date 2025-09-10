defmodule EstoreWeb.Router do
  use EstoreWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {EstoreWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :dav do
    plug(EstoreWeb.Dav)
    plug(EstoreWeb.BasicAuth)
    # plug(:accepts, ["xml"])
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:estore, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: EstoreWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  forward("/.well-known/caldav", Plug.Redirect, to: "/")

  match(:options, "/*path", EstoreWeb.OptionsController, :options)

  scope "/", EstoreWeb do
    pipe_through(:dav)

    match(:propfind, "/*path", DavController, :propfind)
    match(:proppatch, "/*path", DavController, :proppatch)
    match(:mkcol, "/*path", DavController, :mkcol)
    match(:delete, "/*path", DavController, :delete)
    match(:move, "/*path", DavController, :delete)
    match(:copy, "/*path", DavController, :delete)

    match(:get, "/*path", SourceMethods, :get)
    match(:put, "/*path", SourceMethods, :put)

    match(:report, "/*path", ReportMethod, :report)
  end

  # Other scopes may use custom stacks.
  # scope "/api", EstoreWeb do
  #   pipe_through :api
  # end
end
