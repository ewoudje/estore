defmodule EstoreWeb.RecieveMailController do
  use EstoreWeb, :controller

  def post(conn, %{
        "body-mime" => mime,
        "subject" => subject,
        "sender" => sender,
        "recipient" => recipient,
        "signature" => signature,
        "timestamp" => timestamp,
        "token" => token
      }) do
    my_signature =
      :crypto.mac(:hmac, :sha256, Application.fetch_env!(:estore, :mail_key), timestamp <> token)

    if my_signature != Base.decode16!(signature, case: :mixed) do
      Plug.Conn.send_resp(conn, 401, "Unauthorized")
    else
      store_mail(
        Estore.Repo.get_by(Estore.User, username: "admin"),
        signature,
        sender,
        subject,
        recipient,
        mime
      )

      Plug.Conn.send_resp(conn, 200, "Received")
    end
  end

  defp store_mail(user, name, sender, subject, recipient, mime) do
    mails =
      user.resource
      |> Estore.Resource.children()
      |> Ecto.Query.where(name: "mails")
      |> Estore.Repo.one()

    resource =
      Estore.Resource.create(
        mails,
        name,
        false,
        source: Estore.File.source(),
        owner_id: user.principal_id
      )

    Estore.StdProperties.set(resource, name)
    Estore.DeadProperty.set(resource, {{"https://ewoudje.com/ns", "mail-subject"}, [], [subject]})

    {:ok, state} = Estore.Source.write(resource, mime)
    Estore.Source.finish_write(resource, state)
  end
end
