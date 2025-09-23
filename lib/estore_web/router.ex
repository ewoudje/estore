defmodule EstoreWeb.Router do
  use EstoreWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :mail do
    plug(Plug.Parsers, parsers: [:urlencoded, :multipart])
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
    scope "/dev" do
      pipe_through(:browser)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  forward("/.well-known/caldav", Plug.Redirect, to: "/")

  scope "/mail" do
    pipe_through(:mail)
    match(:post, "/mail/mime", EstoreWeb.RecieveMailController, :post)
  end

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
