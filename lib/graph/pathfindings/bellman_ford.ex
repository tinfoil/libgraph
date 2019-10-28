defmodule Graph.Pathfindings.BellmanFord do
  @spec call(Graph.t(), Graph.vertex()) ::
          %{
            optional(Graph.vertex()) => [Graph.vertex()]
          }
          | nil
  def call(%Graph{vertices: vs, edges: edges} = graph, root) do
    predecessors = Map.new()
    distances = %{root => 0}

    {predecessors, distances} =
      Enum.reduce_while(vs, {predecessors, distances}, fn _vertex, acc ->
        Enum.reduce(edges, acc, fn {{u, v}, _}, {predecessors, distances} ->
          weight = Graph.Utils.edge_weight(graph, u, v)
          label_u = Map.get(vs, u)
          label_v = Map.get(vs, v)
          distance_u = Map.get(distances, label_u, :infinite)
          distance_v = Map.get(distances, label_v, :infinite)

          cond do
            distance_u == :infinite ->
              {predecessors, distances}

            distance_v == :infinite or distance_u + weight < distance_v ->
              {
                Map.put(predecessors, label_v, label_u),
                Map.put(distances, label_v, distance_u + weight)
              }

            :else ->
              {predecessors, distances}
          end
        end)
        |> case do
          {^predecessors, ^distances} = result -> {:halt, result}
          result -> {:cont, result}
        end
      end)

    negative_cycle =
      Enum.any?(edges, fn {{u, v}, _} ->
        weight = Graph.Utils.edge_weight(graph, u, v)
        label_u = Map.get(vs, u)
        label_v = Map.get(vs, v)
        distance_u = Map.get(distances, label_u, :infinite)
        distance_v = Map.get(distances, label_v, :infinite)

        cond do
          distance_u == :infinite -> false
          distance_v == :infinite -> false
          distance_u + weight < distance_v -> true
          :else -> false
        end
      end)

    if negative_cycle do
      nil
    else
      Enum.reduce(vs, Map.new(), fn {_id, label}, paths ->
        if Map.get(distances, label, :infinite) == :infinite do
          paths
        else
          Map.put(paths, label, build_path(label, predecessors))
        end
      end)
    end
  end

  defp build_path(vertex, predecessors) do
    do_build_path(vertex, predecessors, [vertex])
  end

  defp do_build_path(vertex, predecessors, path) do
    case Map.get(predecessors, vertex) do
      nil -> path
      next -> do_build_path(next, predecessors, [next | path])
    end
  end
end
