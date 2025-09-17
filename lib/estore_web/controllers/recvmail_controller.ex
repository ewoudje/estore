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
    mySignature =
      :crypto.mac(:hmac, :sha256, Application.fetch_env!(:estore, :mail_key), timestamp <> token)
      |> Base.encode16()

    if mySignature != signature do
      Conn.send_resp(401, "Unauthorized")
    else
      IO.inspect(subject)
      Conn.send_resp(200, "Received")
    end
  end
end
