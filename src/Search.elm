module Search exposing (..)

{-| Intelligent search


# Uninformed search

@docs breadthFirstSearch, breadthFirstTreeSearch, depthFirstSearch, depthFirstTreeSearch


# Informed search


# Accessing progress while searching

This is useful if you want to work with the internal model of the search algorithms from the `Search` module.

For example:

  - For making animations of how the algorithms work.
  - For extensive logging. Or for just displaying the number of explored states.

You can use the functions from this module to embed the inner structure of the search algorithm (the `SearchModel`) into the model of your web application.

Here is a minimal example, which you can also find in the [`Search/ComponentMinimal`](../../../../examples/Search/ComponentMinimal/src/Main.elm) example. A logging use case can be found in the [`Search/Component`](../../../../examples/Search/Component/src/Main.elm) example.

    ...

In this example, the model of the application _is_ the model of the search algorithm. In a real scenario, it would most likely reside as a sub-model within the application model. You can look that up in the [`Search/Component`](../../../../examples/Search/Component/src/Main.elm) example.

@docs treeSearchStep, graphSearchStep

-}

import Dict exposing (Dict)
import List.Extra as List
import Search.Problem as Problem exposing (Node, expand, path)


type alias Problem a b =
    Problem.Problem a b



-- QUEUES


type alias Queue a =
    { pop : List a -> Maybe ( a, List a ) }


{-| simulates a First-In-First-Out queue when using `::` for insertion
-}
fifo : Queue a
fifo =
    { pop = List.unconsLast }


{-| simulates a Last-In-First-Out queue when using `::` for insertion
-}
lifo : Queue a
lifo =
    { pop = List.uncons }


{-| simulates a priority queue when using `::` for insertion
-}
priority : (a -> comparable) -> Queue a
priority f =
    { pop =
        \l ->
            List.minimumBy f l
                |> Maybe.map (\a -> ( a, List.remove a l ))
    }



-- STRATEGIES


type alias Strategy a b =
    { frontier :
        Problem a b
        -> Dict (List ( Float, b )) (List ( Float, b ))
        -> Node a
        -> List (Node a)
        -> List (Node a)
        -> List (Node a)
    }


treeSearch : Strategy a b
treeSearch =
    { frontier = \_ _ _ t childNodes -> List.reverse childNodes ++ t }


{-| Ensures states are not explored twice and always at the lowest known path cost.
-}
graphSearch : Strategy a b
graphSearch =
    { frontier =
        \problem explored h t childNodes ->
            -- only add child node if
            -- a) their state is not the same as their parent's and
            -- b) their state is not in a sibling node with a lower path cost
            -- c) their state is not already explored and
            -- d) their state is not already in the frontier with a lower path cost
            (childNodes
                |> List.filter
                    (\newNode ->
                        -- check parent
                        not
                            (newNode.state == h.state)
                            -- check sibling
                            && not
                                (List.any
                                    (\otherNewNode ->
                                        newNode.state
                                            == otherNewNode.state
                                            && newNode.pathCost
                                            < otherNewNode.pathCost
                                    )
                                    childNodes
                                )
                            -- check explored
                            && not
                                (List.any
                                    (\exploredNode ->
                                        Just (problem.stateToComparable newNode.state)
                                            == Maybe.map Tuple.second (List.head exploredNode)
                                    )
                                    (Dict.keys explored)
                                )
                            -- check frontier
                            && (case List.find (\node -> node.state == newNode.state) t of
                                    Just node ->
                                        newNode.pathCost < node.pathCost

                                    Nothing ->
                                        True
                               )
                    )
                |> List.reverse
            )
                -- if a child node's state is already in the frontier but with a higher pathCost, remove it
                ++ (t
                        |> List.filter
                            (\node ->
                                case List.find (\newNode -> node.state == newNode.state) childNodes of
                                    Just newNode ->
                                        newNode.pathCost >= node.pathCost

                                    Nothing ->
                                        True
                            )
                   )
    }



-- MODEL


type Result a
    = Pending
    | Solution (Node a)
    | Failure


{-| This record represents the inner state of the search algorithm. You can integrate it into the model of your web application.

The `state` parameter refers to the `State` type of the search problem. For example, if you want to search an eight-puzzle, you can import it with `import Search.EightPuzzle exposing (State)`.

Initialize your model with `searchInit` (see below).

-- technically it would suffice to store only explored states and not their children
-- but there is no noticeable difference in performance (TODO benchmarks)
-- and having the children is useful for performant visualization, where we want to reconstruct the search tree

-}
type alias Model a b =
    { strategy : Strategy a b
    , queue : Queue (Node a)
    , problem : Problem a b
    , explored : Dict (List ( Float, b )) (List ( Float, b ))
    , frontier : List (Node a)
    , solution : Result a
    , maxPathCost : Float
    }


{-| Initializes your model of the search algorithm. It takes a `Problem state` as parameter, because it needs to know the `initialState` of the search problem for initializing the frontier, and also the whole other information about the search problem for running the search algorithm later.
-}
init :
    Strategy a b
    -> Queue (Node a)
    -> Problem a b
    -> Model a b
init strategy queue problem =
    { strategy = strategy
    , queue = queue
    , problem = problem
    , explored = Dict.empty
    , frontier =
        [ { state = problem.initialState
          , parent = Nothing
          , pathCost = 0
          }
        ]
    , solution = Pending
    , maxPathCost = 0
    }


searchStep :
    Strategy a comparable
    -> Queue (Node a)
    -> Model a comparable
    -> Model a comparable
searchStep strategy queue ({ problem, explored } as model) =
    case queue.pop model.frontier of
        Just ( h, t ) ->
            let
                childNodes =
                    expand problem h
            in
            { model
                | solution =
                    case List.find (\node -> problem.goalTest node.state) childNodes of
                        Just a ->
                            Solution a

                        Nothing ->
                            model.solution
                , frontier = strategy.frontier problem explored h t childNodes
                , explored =
                    Dict.insert
                        (path h |> List.map (\( pathCost, state ) -> ( pathCost, problem.stateToComparable state )))
                        (childNodes |> List.map (\node -> ( node.pathCost, problem.stateToComparable node.state )))
                        explored
                , maxPathCost = List.foldl max model.maxPathCost (List.map .pathCost childNodes)
            }

        Nothing ->
            { model | solution = Failure }



-- STEPPERS


next : Model a comparable -> Model a comparable
next model =
    searchStep model.strategy model.queue model


nextN : Int -> Model a comparable -> Model a comparable
nextN n model =
    if n > 0 then
        searchStep model.strategy model.queue model |> nextN (n - 1)

    else
        model


nextGoal : Model a comparable -> ( Maybe (Node a), Model a comparable )
nextGoal model =
    let
        newModel =
            next model
    in
    case newModel.solution of
        Solution a ->
            ( Just a, newModel )

        Failure ->
            ( Nothing, newModel )

        Pending ->
            nextGoal newModel



-- INTERFACE


breadthFirst : Problem a comparable -> Model a comparable
breadthFirst =
    init graphSearch fifo


depthFirst : Problem a comparable -> Model a comparable
depthFirst =
    init graphSearch lifo


{-| Dijkstra's algorithm.
-}
uniformCost : Problem a comparable -> Model a comparable
uniformCost =
    init graphSearch (priority (\node -> node.pathCost))


greedy : Problem a comparable -> Model a comparable
greedy problem =
    init graphSearch
        (priority (\node -> problem.heuristic node.state))
        problem


{-| A\* search.
-}
bestFirst : Problem a comparable -> Model a comparable
bestFirst problem =
    init
        graphSearch
        (priority (\node -> node.pathCost + problem.heuristic node.state))
        problem
