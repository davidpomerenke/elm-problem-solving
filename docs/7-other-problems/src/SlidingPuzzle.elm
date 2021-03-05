module SlidingPuzzle exposing (..)

import Problem.Example exposing (..)
import Problem.Search as Search exposing (Result(..))
import Problem.Search.Dashboard as Dashboard exposing (Search(..), Visual(..))


main =
    Dashboard.document
        { problem = complexEightPuzzle
        , problemStateToHtml = Just slidingPuzzleVisual
        , searches = [ UniformCost, BestFirst, Greedy ]
        , visuals = [ Scatter, TreeMap, Graph ]
        }
