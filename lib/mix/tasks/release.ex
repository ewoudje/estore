defmodule Mix.Tasks.NewVersion do
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    version = Estore.MixProject.version()
    [l, m, s] = String.split(version, ".")
    s = Integer.to_string(String.to_integer(s) + 1)
    new_version = Enum.join([l, m, s], ".")

    Estore.MixProject.set_version(new_version)
    Mix.Shell.cmd("git add README.md")
    Mix.Shell.cmd("git commit -m \"New v#{version}\"")
    Mix.Shell.cmd("git tag v#{version}")
    Mix.Shell.cmd("git push")
    Mix.Shell.cmd("git push origin v#{version}")
  end
end
