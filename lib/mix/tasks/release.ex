defmodule Mix.Tasks.NewVersion do
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    version = Estore.MixProject.version()
    [l, m, s] = String.split(version, ".")
    s = Integer.to_string(String.to_integer(s) + 1)
    new_version = Enum.join([l, m, s], ".")

    Estore.MixProject.set_version(new_version)
    Mix.Shell.cmd("git add README.md", &:ok)
    Mix.Shell.cmd("git commit -m \"New v#{version}\"", &:ok)
    Mix.Shell.cmd("git tag v#{version}", &:ok)
    Mix.Shell.cmd("git push", &:ok)
    Mix.Shell.cmd("git push origin v#{version}", &:ok)
  end
end
