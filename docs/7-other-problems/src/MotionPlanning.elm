module MotionPlanning exposing (..)

import Problem.Example exposing (..)
import Problem.Search as Search exposing (Result(..))
import Problem.Search.Dashboard as Dashboard exposing (Search(..), Visual(..))


main =
    Dashboard.document
        { problem = simpleMotionPlanning
        , problemStateToHtml = Nothing
        , searches = [ UniformCost, BestFirst, Greedy ]
        , visuals = [ Scatter, TreeMap, Graph ]
        }
