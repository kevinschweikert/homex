defmodule Homex.Entity do
  @moduledoc """
  The behaviour and the struct for an entity, and the scaffolding to add new
  entity kinds.

  An entity is one module that does `use` on a kind, for example
  `Homex.Entity.Switch`. The kind supplies the `c:validate/1`, `c:describe/1`,
  `c:setup/1` and `c:handle_command/2` callbacks, and generates a `new/1`
  constructor for the module.

  Your module can implement the optional callbacks `handle_init/1`,
  `handle_info/2`, `handle_call/2` and `handle_cast/2`. It can also implement the
  hooks that the kind adds, for example `handle_on/1` on a switch.

  ## Adding a kind

  `use Homex.Entity` adopts this behaviour and declares the optional callbacks.
  The kind then writes its own `__using__/1` that calls `__entity__/3`. That macro
  generates `new/1`, delegates `setup/1` and `handle_command/2`, and adds an
  overridable default for each optional callback.

      defmodule MyApp.Counter do
        use Homex.Entity

        @opts_schema Homex.Entity.base_opts_schema() |> NimbleOptions.new!()

        defmacro __using__(opts), do: Homex.Entity.__entity__(__MODULE__, opts, set_count: 2)

        @impl Homex.Entity
        def validate(opts), do: NimbleOptions.validate(opts, @opts_schema)

        @impl Homex.Entity
        def describe(opts) do
          %Homex.Descriptor{
            kind: :sensor,
            name: opts[:name],
            fields: %{state: :state},
            options: %{},
            transport: %{}
          }
        end

        @impl Homex.Entity
        def setup(%{module: module} = entity), do: module.handle_init(entity)

        @impl Homex.Entity
        def handle_command(_cmd, entity), do: entity

        def set_count(entity, count), do: Homex.Entity.put_change(entity, :state, count)
      end

  A module that uses the kind gets `new/1`, the callback defaults, and the
  functions in the import list of `__entity__/3`:

      defmodule MyApp.Clicks do
        use MyApp.Counter, id: :clicks, name: "Clicks"

        def handle_info({:clicked, count}, entity), do: set_count(entity, count)
      end

  `Homex.Entity.Sensor` has no hooks. `Homex.Entity.Switch` has hooks. Use them as
  the larger examples.

  A kind calls a hook directly, for example `entity.module.handle_on(entity)`. The
  call always resolves, because `__entity__/3` puts a default for each hook in the
  module. An override can call the default with `super/1`.
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
      descriptor = %{kind.describe(validated) | id: validated[:id], device: validated[:device]}
      {:ok, %__MODULE__{module: module, descriptor: descriptor}}
    end
  end

  @doc "The current values of the entity, or `nil` when it is no longer running"
  @spec snapshot(atom()) :: map() | nil
  def snapshot(id) do
    case Homex.call(id, {:homex, :snapshot}) do
      %{} = values -> values
      {:error, :not_found} -> nil
    end
  end

  @doc "Delivers a command map to the entity"
  @spec send_command(atom(), map()) :: :ok | {:error, :not_found}
  def send_command(id, cmd) do
    Homex.notify(id, {:homex, :command, cmd})
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

  @doc """
  The options that every entity kind accepts.

  A kind merges its own options into this list, then builds its schema from the
  result.
  """
  @spec base_opts_schema() :: keyword()
  def base_opts_schema do
    [
      id: [
        required: true,
        type: :atom,
        doc: "the unique id of the entity, used as the registry lookup key"
      ],
      name: [required: true, type: :string, doc: "the display name of the entity"],
      device: [
        required: false,
        type: :atom,
        default: :default,
        doc: "the id of the device this entity belongs to"
      ]
    ]
  end

  @doc """
  Stages a value for one field of the entity.

  Homex commits the staged values after your callback returns, then publishes the
  fields that changed. It ignores a key that the `:fields` of the
  `Homex.Descriptor` do not list.

  A kind wraps this function in a helper, for example
  `Homex.Entity.Sensor.set_value/2`.
  """
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

    values = Map.merge(values, diff)

    if map_size(diff) != 0 do
      Homex.broadcast({:homex, :state, entity.descriptor, values, diff})
    end

    %{entity | changes: %{}, values: values}
  end

  ## Process lifecycle

  def child_spec(%__MODULE__{} = entity) do
    %{
      id: {__MODULE__, entity.descriptor.id},
      start: {__MODULE__, :start_link, [entity]},
      restart: :transient
    }
  end

  def start_link(%__MODULE__{} = entity), do: GenServer.start_link(__MODULE__, entity)

  @impl GenServer
  def init(%__MODULE__{module: module, descriptor: descriptor} = entity) do
    with {:ok, _pid} <-
           Registry.register(Homex.EntityRegistry, descriptor.id, descriptor) do
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
    Registry.unregister(Homex.EntityRegistry, entity.descriptor.id)
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
