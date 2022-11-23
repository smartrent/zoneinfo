defmodule Zoneinfo.Cache do
  use GenServer

  @moduledoc false

  @table __MODULE__
  @ttl_seconds 60 * 60 * 24

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Return the information for a time zone
  """
  @spec get(binary) :: {:ok, Zoneinfo.TZif.t()} | {:error, File.posix() | :invalid}
  def get(time_zone) when is_binary(time_zone) do
    case :ets.lookup(@table, time_zone) do
      [{^time_zone, tzif}] ->
        {:ok, tzif}

      _ ->
        GenServer.call(__MODULE__, {:load, time_zone})
    end
  rescue
    ArgumentError ->
      # GenServer crashed. Try to load manually.
      load_time_zone(time_zone)
  end

  @doc """
  Manually garbage collect the cache

  This is useful if you know that the time zone files changed
  and should be reloaded on the next operation.
  """
  @spec gc() :: :ok
  def gc() do
    GenServer.call(__MODULE__, :gc)
  end

  @doc """
  Return Zoneinfo metadata on a time zone
  """
  @spec meta(String.t()) :: {:ok, Zoneinfo.Meta.t()} | {:error, atom()}
  def meta(time_zone) do
    with {:ok, tzif} <- get(time_zone) do
      {:ok, Zoneinfo.Meta.to_meta(time_zone, tzif)}
    end
  end

  @impl GenServer
  def init(_args) do
    @table = :ets.new(@table, [:set, :protected, :named_table])
    gc_timer_ref = schedule_gc()

    {:ok, gc_timer_ref}
  end

  @impl GenServer
  def handle_call({:load, time_zone}, _from, gc_timer_ref) do
    result = load_time_zone(time_zone)

    case result do
      {:ok, tzif} ->
        :ets.insert(@table, {time_zone, tzif})

      _ ->
        :ok
    end

    {:reply, result, gc_timer_ref}
  end

  def handle_call(:gc, _from, gc_timer_ref) do
    _ = Process.cancel_timer(gc_timer_ref)

    run_gc()
    gc_timer_ref = schedule_gc()

    {:reply, :ok, gc_timer_ref}
  end

  @impl GenServer
  def handle_info(:gc, _gc_timer_ref) do
    run_gc()
    gc_timer_ref = schedule_gc()

    {:noreply, gc_timer_ref}
  end

  defp run_gc() do
    # Everything gets erased at the same time to keep this simple
    :ets.delete_all_objects(@table)
  end

  defp schedule_gc() do
    Process.send_after(self(), :gc, @ttl_seconds * 1000)
  end

  defp load_time_zone(time_zone) do
    Zoneinfo.tzpath()
    |> Path.join(time_zone)
    |> File.open(&load_tzif/1)
    |> case do
      {:ok, result} -> result
      {:error, _} = error -> error
    end
  end

  # :all will be deprecated in Elixir v1.17 but fails dialyzer.
  # :eof is only available in >= 1.13, so conditionally use it
  @binread_all if Version.match?(System.version(), ">= 1.13.0"), do: :eof, else: :all

  defp load_tzif(io) do
    with header when is_binary(header) and byte_size(header) == 8 <- IO.binread(io, 8),
         {:ok, _version} <- Zoneinfo.TZif.version(header),
         rest when is_binary(rest) <- IO.binread(io, @binread_all) do
      Zoneinfo.TZif.parse(header <> rest)
    else
      _error -> {:error, :invalid}
    end
  end
end
