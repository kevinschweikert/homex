defmodule Homex.Entity do
  @moduledoc """
  Defines the behaviour and struct for an entity, and the scaffolding for
  authoring entity kinds.

  An entity is backed by a single `module` that `use`s a kind such as
  `Homex.Entity.Switch`. It implements the required `c:new/1`, `c:setup/1` and
  `c:handle_command/2` callbacks (the kind supplies `setup`/`handle_command`
  via `use`) and may implement the optional handler callbacks (`handle_init`,
  `handle_info`, `handle_call`, `handle_cast`) plus any kind-specific hooks
  like `handle_on/1`.

  ## Authoring a kind

  `use Homex.Entity` adopts this behaviour and declares the optional handler
  callbacks. The kind then writes its own `__using__/1` that splices in
  `__entity__/3` — which generates `new/1`, delegates `setup`/`handle_command`,
  and injects overridable identity defaults — alongside its own hook defaults.
  `Homex.Entity.Sensor` (no hooks) and `Homex.Entity.Switch` (with hooks) are
  the worked examples.

  A kind reaches a hook with a plain call, `entity.module.handle_on(entity)`,
  which always resolves because those defaults are injected into every user
  module; overrides can chain to them with `super/1`.
  """
  use GenServer

  @doc "Validate the options give to this entity"
  @callback validate(opts :: keyword()) :: {:ok, opts :: keyword()} | {:error, term()}

  @doc "Describes the entity from validated options"
  @callback describe(opts :: keyword()) :: Homex.Descriptor.t()

  @doc """
  Configures the initial state for the entity
  """
  @callback setup(entity :: t()) :: entity :: t()

  @callback handle_command(cmd :: map(), entity :: t()) :: entity :: t()

  @type t() :: %__MODULE__{
          module: module() | nil,
          values: map(),
          changes: map(),
          private: map(),
          descriptor: Homex.Descriptor.t()
        }

  defstruct [
    :module,
    :descriptor,
    values: %{},
    changes: %{},
    private: %{}
  ]

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Homex.Entity
      def new(opts), do: Homex.Entity.__new__(__MODULE__, __MODULE__, opts)

      @doc "Gets called after the entity started"
      @callback handle_init(entity :: Homex.Entity.t()) :: Homex.Entity.t()

      @doc """
      Gets called for any `send/2` message the entity process receives that homex does not
      handle itself
      """
      @callback handle_info(msg :: term(), entity :: Homex.Entity.t()) :: Homex.Entity.t()

      @doc """
      Gets called for `GenServer.call/2` messages to the entity. Returns the reply
      and the entity
      """
      @callback handle_call(msg :: term(), entity :: Homex.Entity.t()) ::
                  {reply :: term(), Homex.Entity.t()}

      @doc "Gets called for `GenServer.cast/2` messages to the entity"
      @callback handle_cast(msg :: term(), entity :: Homex.Entity.t()) :: Homex.Entity.t()

      @optional_callbacks handle_init: 1, handle_info: 2, handle_call: 2, handle_cast: 2
    end
  end

  @doc """
  Shared scaffolding a kind splices into its own `__using__/1`.

  Wires up the behaviour, a runtime `new/1`, the `setup`/`handle_command`
  delegations, and overridable identity defaults for the platform-independent
  callbacks. A kind adds its own hook defaults (e.g. `handle_on/1`) alongside.
  """
  def __entity__(kind, using_opts, imports \\ []) do
    quote generated: true do
      @behaviour unquote(kind)

      @doc false
      def __homex_entity__, do: true

      import unquote(kind), only: unquote(imports)
      import Homex.Entity, only: [put_private: 3, get_private: 2]
      alias Homex.Entity

      def new(opts \\ []) do
        Homex.Entity.__new__(
          unquote(kind),
          __MODULE__,
          Keyword.merge(unquote(using_opts), opts)
        )
      end

      defdelegate validate(opts), to: unquote(kind)
      defdelegate setup(entity), to: unquote(kind)
      defdelegate handle_command(cmd, entity), to: unquote(kind)

      # Overridable defaults so every callback resolves to a real function (no
      # reflection at dispatch) and overrides can chain with super/1.
      def handle_init(entity), do: entity
      def handle_info(_msg, entity), do: entity
      def handle_call(_msg, entity), do: {{:error, :not_handled}, entity}
      def handle_cast(_msg, entity), do: entity
      defoverridable handle_init: 1, handle_info: 2, handle_call: 2, handle_cast: 2
    end
  end

  ## Public API

  @doc """
  Normalizes an entity spec into a `%Homex.Entity{}`.

  Accepts a ready-made struct, a `{module, opts}` pair, or a bare module whose
  options were baked in at `use` time. The module must be runnable: a
  `use`-based module or `Homex.Entity.DeviceTrigger`. A plain kind module such
  as `Homex.Entity.Switch` returns `{:error, :entity_not_runnable}` — it has to
  be `use`d.
  """
  @spec new(t() | {module(), keyword()} | module()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = entity), do: {:ok, entity}
  def new({module, opts}) when is_atom(module) and is_list(opts), do: from_module(module, opts)
  def new(module) when is_atom(module), do: from_module(module, [])

  defp from_module(module, opts) do
    cond do
      not (Code.ensure_loaded?(module) and function_exported?(module, :new, 1)) ->
        {:error, :entity_invalid}

      # A plain kind module builds a struct but has no handlers to dispatch to,
      # so it would crash at boot. Only `use`-based modules and DeviceTrigger
      # carry the marker that opts them into being run directly.
      not function_exported?(module, :__homex_entity__, 0) ->
        {:error, :entity_not_runnable}

      true ->
        module.new(opts)
    end
  end

  @doc false
  def __new__(kind, module, opts) do
    with {:ok, validated} <- kind.validate(opts) do
      descriptor = %{kind.describe(validated) | device: validated[:device]}
      {:ok, %__MODULE__{module: module, descriptor: descriptor}}
    end
  end

  @doc "The current values of the entity"
  def snapshot(name), do: Homex.call(name, {:homex, :snapshot})

  @doc "Delivers a command map to the entity"
  def send_command(name, cmd) do
    Homex.notify(name, {:homex, :command, cmd})
  end

  @doc """
  Puts a value into the Entity struct to retrieve it later. Can be used as a key-value store for user data
  """
  @spec put_private(t(), atom(), term()) :: t()
  def put_private(%__MODULE__{private: private} = entity, key, value) when is_atom(key) do
    private = Map.put(private, key, value)
    %{entity | private: private}
  end

  @doc """
  Gets the value from the Entity struct
  """
  @spec get_private(t(), atom()) :: term()
  def get_private(%__MODULE__{private: private}, key) when is_atom(key) do
    Map.get(private, key)
  end

  ## Platform API

  @doc false
  def base_opts_schema do
    [
      name: [required: true, type: :string, doc: "the name of the entity"],
      device: [
        required: false,
        type: :atom,
        default: nil,
        doc: "the nested device which the entity should be associcated with"
      ]
    ]
  end

  @doc false
  @spec put_change(t(), atom(), term()) :: t()
  def put_change(
        %__MODULE__{changes: changes, descriptor: %Homex.Descriptor{fields: fields}} = entity,
        key,
        value
      )
      when is_atom(key) do
    if Map.has_key?(fields, key) do
      changes = Map.put(changes, key, value)
      %{entity | changes: changes}
    else
      entity
    end
  end

  @doc false
  @spec execute_change(t()) :: t()
  def execute_change(
        %__MODULE__{
          values: values,
          changes: changes,
          descriptor: %Homex.Descriptor{fields: fields}
        } = entity
      ) do
    diff =
      for {key, value} <- changes, fields[key] == :event or values[key] != value, into: %{} do
        {key, value}
      end

    if map_size(diff) != 0 do
      for {module, instance} <- Homex.adapters() do
        module.publish_state(instance, entity.descriptor, diff)
      end
    end

    %{entity | changes: %{}, values: Map.merge(values, diff)}
  end

  ## Process lifecycle

  def via(name), do: {:via, Registry, {Homex.EntityRegistry, name}}
  def via(name, meta), do: {:via, Registry, {Homex.EntityRegistry, name, meta}}

  def child_spec(%__MODULE__{} = entity) do
    %{
      id: {__MODULE__, entity.descriptor.name},
      start: {__MODULE__, :start_link, [entity]},
      restart: :transient
    }
  end

  def start_link(%__MODULE__{} = entity), do: GenServer.start_link(__MODULE__, entity)

  @impl GenServer
  def init(%__MODULE__{module: module} = entity) do
    descriptor =
      Homex.Descriptor.put_unique_id(entity.descriptor, Homex.device())

    with {:ok, _pid} <-
           Registry.register(Homex.EntityRegistry, descriptor.name, descriptor) do
      values = Map.new(descriptor.fields, fn {key, _kind} -> {key, nil} end)
      entity = %{entity | descriptor: descriptor, values: values}
      {:ok, entity |> module.setup() |> execute_change()}
    end
  end

  @impl GenServer
  def handle_call({:homex, :snapshot}, _from, entity) do
    {:reply, entity.values, entity}
  end

  # unregistering here is synchronous, unlike the registry cleanup after death
  def handle_call({:homex, :remove}, _from, entity) do
    Registry.unregister(Homex.EntityRegistry, entity.descriptor.name)
    {:stop, :normal, :ok, entity}
  end

  def handle_call(msg, _from, %{module: module} = entity) do
    {reply, entity} = module.handle_call(msg, entity)
    {:reply, reply, execute_change(entity)}
  end

  @impl GenServer
  def handle_cast(msg, %{module: module} = entity) do
    {:noreply, module.handle_cast(msg, entity) |> execute_change()}
  end

  @impl GenServer
  def handle_info({:homex, :command, cmd}, %{module: module} = entity) do
    entity = module.handle_command(cmd, entity) |> execute_change()
    {:noreply, entity}
  end

  # Fallback, passes the info msg along to the entity module
  def handle_info(msg, %{module: module} = entity) do
    {:noreply, module.handle_info(msg, entity) |> execute_change()}
  end
end
