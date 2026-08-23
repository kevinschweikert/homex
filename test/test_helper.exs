# TODO: find a way not to replicate the supervisions tree again
{:ok, _} =
  Supervisor.start_link(
    [
      {Registry, name: Homex.EntityRegistry, keys: :unique, meta: [node_id: "test"]},
      {Registry, name: Homex.Subscribers, keys: :duplicate},
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Homex.AdapterSupervisor, strategy: :one_for_one}
    ],
    strategy: :one_for_one
  )

ExUnit.start()
