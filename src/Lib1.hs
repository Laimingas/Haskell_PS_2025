module Lib1
    ( examples, Command(..), Dumpable(..)
    ) where

data Dumpable = Examples
  deriving Show

data Command
  = CreateWorkout String [Command]
  | AddExerciseWithWeight String Int Int Int  
  | AddExerciseNoWeight String Int Int         
  | RemoveExercise String
  | StartWorkout String
  | StopWorkout String
  | ShowAllWorkouts
  | ShowWorkout String
  | SelectWorkout String [Command]
  | Dump Dumpable
  deriving Show

examples :: [Command]
examples =
  [ CreateWorkout "Morning Routine"
      [ AddExerciseNoWeight "Push-ups" 3 15
      , AddExerciseNoWeight "Squats" 3 20
      , CreateWorkout "Upper Body Blast"   
          [ AddExerciseWithWeight "Bench Press" 3 10 50
          , AddExerciseWithWeight "Pull-ups" 3 8 0
          ]
      ]
  , SelectWorkout "Morning Routine"
      [ AddExerciseWithWeight "Deadlift" 5 5 100
      , RemoveExercise "Push-ups"
      , CreateWorkout "Leg Day"
          [ AddExerciseNoWeight "Lunges" 3 12 ]
      ]
  , ShowAllWorkouts
  , ShowWorkout "Morning Routine"
  , StartWorkout "Morning Routine"
  , StopWorkout "Morning Routine"
  , Dump Examples
  ]
