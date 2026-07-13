{:ok, _} =
  Supervisor.start_link(
    [
      {Registry,
       name: Homex.EntityRegistry,
       keys: :unique,
       meta: [adapters: [{Homex.Adapter.Test, Homex.Adapter.Test}]]},
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      Homex.Adapter.Test
    ],
    strategy: :one_for_one
  )

ExUnit.start()
