defmodule Graph.Pathfindings.Dijkstra do
  @moduledoc """
  This module contains implementation code for path finding algorithms used by `libgraph`.
  """
  import Graph.Utils, only: [vertex_id: 1, edge_weight: 3]

  @type heuristic_fun :: (Graph.vertex() -> integer)

  @compile {:inline, do_bfs: 4, construct_path: 3, construct_path: 4, calculate_cost: 4}
  @doc """
  Finds the shortest path between `a` and all other reachable vertices, returning a map from vertex to path.
  Returns `nil` if no paths can be found.

  The shortest path is calculated here by using a cost function to choose
  which path to explore next. The cost function in Dijkstra's algorithm is
  `weight(E(A, B))+lower_bound(E(A, B))` where `lower_bound(E(A, B))` is always 0.
  """
  @spec call(Graph.t(), Graph.vertex()) :: %{optional(Graph.vertex()) => [Graph.vertex()]} | nil
  def call(%Graph{} = g, a) do
    a_star(g, a, fn _v -> 0 end)
  end

  @doc """
  Finds the shortest path between `a` and all other vertices.
  Returns `nil` if paths cannot be found.

  This implementation takes a heuristic function which allows you to
  calculate the lower bound cost of a given vertex `v`. The algorithm
  then uses that lower bound function to determine which path to explore
  next in the graph.

  The `dijkstra` function is simply `a_star` where the heuristic function
  always returns 0, and thus the next vertex is chosen based on the weight of
  the edge between it and the current vertex.


  """
  @spec a_star(Graph.t(), Graph.vertex(), heuristic_fun) ::
          %{
            optional(Graph.vertex()) => [Graph.vertex()]
          }
          | nil
  def a_star(%Graph{vertices: vertices, out_edges: out_edges} = graph, a, hfun)
      when is_function(hfun, 1) do
    with a_id <- vertex_id(a),
         {:ok, vertex_a_out_edges} <- Map.fetch(out_edges, a_id) do
      shortest_path_tree =
        Graph.new()
        |> Graph.add_vertex(a_id)

      initialized_queue =
        Enum.reduce(vertex_a_out_edges, PriorityQueue.new(), fn b_id, queue ->
          queue_cost = calculate_cost(graph, a_id, b_id, hfun)
          a_to_b_weight = edge_weight(graph, a_id, b_id)

          PriorityQueue.push(
            queue,
            {a_id, b_id, a_to_b_weight},
            queue_cost
          )
        end)

      complete_spt =
        do_bfs(
          initialized_queue,
          graph,
          shortest_path_tree,
          hfun
        )

      to_path_map(complete_spt, vertices)
    else
      _ ->
        nil
    end
  end

  # Graph inspection convenience method
  def id_graph_to_original(
        %Graph{edges: edges, vertices: vertices},
        vs
      ) do
    collected_vertices =
      Enum.reduce(vertices, Graph.new(), fn {_orig, vertex}, graph ->
        Graph.add_vertex(graph, Map.get(vs, vertex))
      end)

    final_graph =
      edges
      |> Map.keys()
      |> Enum.reduce(collected_vertices, fn {v_from, v_to}, graph ->
        original_from = Map.get(vs, Map.get(vertices, v_from))
        original_to = Map.get(vs, Map.get(vertices, v_to))

        Graph.add_edge(graph, Graph.Edge.new(original_from, original_to))
      end)

    final_graph
  end

  ## Private

  defp calculate_cost(%Graph{vertices: vertices} = g, v1_id, v2_id, hfun) do
    edge_weight(g, v1_id, v2_id) + hfun.(Map.get(vertices, v2_id))
  end

  defp do_bfs(
         queue,
         %Graph{out_edges: oe} = graph,
         %Graph{vertices: spt_vertices} = shortest_path_tree,
         hfun
       ) do
    case PriorityQueue.pop(queue) do
      {{:value, {a_id, b_id, a_to_b_weight}}, remaining_queue} ->
        b_id_in_spt = Graph.Utils.vertex_id(b_id)

        if Map.has_key?(spt_vertices, b_id_in_spt) do
          do_bfs(remaining_queue, graph, shortest_path_tree, hfun)
        else
          case Map.get(oe, b_id) do
            nil ->
              updated_shortest_path_tree =
                shortest_path_tree
                |> Graph.add_vertex(b_id)
                |> Graph.add_edge(b_id, a_id)

              do_bfs(remaining_queue, graph, updated_shortest_path_tree, hfun)

            b_out ->
              updated_shortest_path_tree =
                shortest_path_tree
                |> Graph.add_vertex(b_id)
                |> Graph.add_edge(b_id, a_id)

              new_queue =
                Enum.reduce(b_out, remaining_queue, fn c_id, queue_acc ->
                  queue_cost = a_to_b_weight + calculate_cost(graph, b_id, c_id, hfun)

                  PriorityQueue.push(
                    queue_acc,
                    {b_id, c_id, a_to_b_weight + edge_weight(graph, b_id, c_id)},
                    queue_cost
                  )
                end)

              do_bfs(new_queue, graph, updated_shortest_path_tree, hfun)
          end
        end

      {:empty, _} ->
        shortest_path_tree
    end
  end

  defp construct_path(
         v_id_spt,
         vertices,
         %Graph{} = shortest_path_tree
       ) do
    construct_path(v_id_spt, vertices, shortest_path_tree, [])
  end

  defp construct_path(
         v_id_spt,
         vertices,
         %Graph{vertices: vertices_spt, out_edges: out_edges_spt} = shortest_path_tree,
         path
       ) do
    v_id_actual = Map.get(vertices_spt, v_id_spt)
    vertex = Map.get(vertices, v_id_actual)

    case vertex do
      nil ->
        path

      valid_vertex ->
        updated_path = [valid_vertex | path]

        explorable_edges =
          out_edges_spt
          |> Map.get(v_id_spt, MapSet.new())
          |> MapSet.to_list()

        case explorable_edges do
          [] ->
            updated_path

          [next_v_id_spt] ->
            construct_path(next_v_id_spt, vertices, shortest_path_tree, updated_path)
        end
    end
  end

  defp to_path_map(
         %Graph{vertices: vertices_spt} = shortest_path_tree,
         vertices
       ) do
    Enum.reduce(vertices_spt, %{}, fn {v_id_spt, v_id}, acc ->
      path = construct_path(v_id_spt, vertices, shortest_path_tree)
      vertex = Map.get(vertices, v_id)

      Map.put(acc, vertex, path)
    end)
  end
end
