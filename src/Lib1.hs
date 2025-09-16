module Lib1
    ( examples, Command(..)
    ) where


data Command
  = CreateWorkout String
  | AddExerciseWithWeight String Int Int Int String  
  | AddExerciseNoWeight String Int Int String         
  | AddSubWorkout String String
  | RemoveExercise String String
  | StartWorkout String
  | StopWorkout String
  | ShowAllWorkouts
  | ShowWorkout String
  | DumpExamples
  deriving (Show, Eq)


examples :: [Command]
examples =
  [ CreateWorkout "Morning Routine"
  , AddExerciseNoWeight "Push-ups" 3 15 "Morning Routine"
  , AddExerciseWithWeight "Squats" 3 20 50 "Morning Routine"
  , CreateWorkout "Upper Body Blast"
  , AddSubWorkout "Upper Body Blast" "Morning Routine"
  , ShowAllWorkouts
  , ShowWorkout "Morning Routine"
  , StartWorkout "Morning Routine"
  , StopWorkout "Morning Routine"
  , DumpExamples
  ]
