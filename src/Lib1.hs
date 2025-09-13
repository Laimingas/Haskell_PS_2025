module Lib1
    ( examples, Command(..)
    ) where


data Command
  = CreateWorkout String
  | AddExercise String Int Int (Maybe Int) String
  | AddSubWorkout String String
  | RemoveExercise String String
  | StartWorkout String
  | StopWorkout String
  | DumpExamples
  deriving Show

examples :: [Command]
examples =
  [ CreateWorkout "Morning Routine"
  , AddExercise "Push-ups" 3 15 Nothing "Morning Routine"
  , AddExercise "Squats" 3 20 Nothing "Morning Routine"
  , CreateWorkout "Upper Body Blast"
  , AddSubWorkout "Upper Body Blast" "Morning Routine"
  , StartWorkout "Morning Routine"
  , StopWorkout "Morning Routine"
  , DumpExamples
  ]
