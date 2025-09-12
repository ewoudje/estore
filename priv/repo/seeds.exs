# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Estore.Repo.insert!(%Estore.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

Estore.Source.new(Estore.File)
Estore.Source.new(Estore.Calendar)
Estore.Source.new(Estore.User)

root = Estore.Resource.create_root()
users = Estore.Resource.create(root, "users", true)
admin = Estore.Resource.create(users, "admin", true, source: Estore.User.source())

calendar =
  Estore.Resource.create(admin, "calendar", true, source: Estore.Calendar.source(), owner: admin)

Estore.Calendar.configure_calendar_root(calendar)
Estore.StdProperties.set(root, "root")
Estore.StdProperties.set(calendar, "calendar")
Estore.StdProperties.set(admin, "admin")
Estore.StdProperties.set(users, "users")

Estore.User.create_user(%{
  username: "admin",
  password_hash: Pbkdf2.hash_pwd_salt("admin", rounds: 50_000),
  principal_id: admin.id
})
