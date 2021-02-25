defmodule Zoneinfo.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {Zoneinfo.Cache, []}
    ]

    opts = [strategy: :one_for_one, name: Zoneinfo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
