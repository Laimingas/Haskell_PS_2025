{-# LANGUAGE GADTs, DeriveFunctor, FlexibleContexts #-}

module WorkoutDSL
  ( WorkoutF(..), WorkoutFree, createWorkout, selectWorkout, addExerciseWithWeight
  , addExerciseNoWeight, removeExercise, startWorkout, stopWorkout
  , showAllWorkouts, showWorkout, dumpExamples
  , runHttpInterpreter, runPureInterpreter
  ) where

import qualified Lib1
import qualified Lib2
import qualified Lib3
import Control.Monad.Free

-- ==============================================
-- Free Monad DSL definition
-- ==============================================

data WorkoutF next where
  CreateWorkout         :: String -> [Lib1.Command] -> (String -> next) -> WorkoutF next
  SelectWorkout         :: String -> [Lib1.Command] -> (String -> next) -> WorkoutF next
  AddExerciseWithWeight :: String -> Int -> Int -> Int -> (String -> next) -> WorkoutF next
  AddExerciseNoWeight   :: String -> Int -> Int -> (String -> next) -> WorkoutF next
  RemoveExercise        :: String -> (String -> next) -> WorkoutF next
  StartWorkout          :: String -> (String -> next) -> WorkoutF next
  StopWorkout           :: String -> (String -> next) -> WorkoutF next
  ShowAllWorkouts       :: (String -> next) -> WorkoutF next
  ShowWorkout           :: String -> (String -> next) -> WorkoutF next
  DumpExamples          :: (String -> next) -> WorkoutF next
  deriving Functor

type WorkoutFree = Free WorkoutF

createWorkout :: String -> [Lib1.Command] -> WorkoutFree String
createWorkout n cs = liftF (CreateWorkout n cs id)

selectWorkout :: String -> [Lib1.Command] -> WorkoutFree String
selectWorkout n cs = liftF (SelectWorkout n cs id)

addExerciseWithWeight :: String -> Int -> Int -> Int -> WorkoutFree String
addExerciseWithWeight a s r w = liftF (AddExerciseWithWeight a s r w id)

addExerciseNoWeight :: String -> Int -> Int -> WorkoutFree String
addExerciseNoWeight a s r = liftF (AddExerciseNoWeight a s r id)

removeExercise :: String -> WorkoutFree String
removeExercise a = liftF (RemoveExercise a id)

startWorkout :: String -> WorkoutFree String
startWorkout n = liftF (StartWorkout n id)

stopWorkout :: String -> WorkoutFree String
stopWorkout n = liftF (StopWorkout n id)

showAllWorkouts :: WorkoutFree String
showAllWorkouts = liftF (ShowAllWorkouts id)

showWorkout :: String -> WorkoutFree String
showWorkout n = liftF (ShowWorkout n id)

dumpExamples :: WorkoutFree String
dumpExamples = liftF (DumpExamples id)

-- ==============================================
-- Interpreter 1: HTTP client based (uses send function)
-- ==============================================

-- sendAction :: Lib1.Command -> IO String
runHttpInterpreter :: (Lib1.Command -> IO String) -> WorkoutFree a -> IO a
runHttpInterpreter sendAction = iterM interp
  where
    interp (CreateWorkout n cs next)            = sendAction (Lib1.CreateWorkout n cs)         >>= next
    interp (SelectWorkout n cs next)            = sendAction (Lib1.SelectWorkout n cs)         >>= next
    interp (AddExerciseWithWeight a s r w next) = sendAction (Lib1.AddExerciseWithWeight a s r w) >>= next
    interp (AddExerciseNoWeight a s r next)     = sendAction (Lib1.AddExerciseNoWeight a s r)  >>= next
    interp (RemoveExercise a next)              = sendAction (Lib1.RemoveExercise a)           >>= next
    interp (StartWorkout n next)                = sendAction (Lib1.StartWorkout n)             >>= next
    interp (StopWorkout n next)                 = sendAction (Lib1.StopWorkout n)              >>= next
    interp (ShowAllWorkouts next)               = sendAction Lib1.ShowAllWorkouts              >>= next
    interp (ShowWorkout n next)                 = sendAction (Lib1.ShowWorkout n)              >>= next
    interp (DumpExamples next)                  = sendAction (Lib1.Dump Lib1.Examples)         >>= next

-- ==============================================
-- Interpreter 2: Pure domain interpreter with state (same as server, but no IO)
-- ==============================================

-- The pure interpreter feeds CLI output string to next step ("Lib2.process" returns [String])
runPureInterpreter :: Lib3.State -> WorkoutFree a -> (a, Lib3.State)
runPureInterpreter st (Pure a) = (a, st)
runPureInterpreter st (Free (CreateWorkout n cs next)) =
  let cmd  = Lib1.CreateWorkout n cs
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (SelectWorkout n cs next)) =
  let cmd  = Lib1.SelectWorkout n cs
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (AddExerciseWithWeight a s r w next)) =
  let cmd  = Lib1.AddExerciseWithWeight a s r w
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (AddExerciseNoWeight a s r next)) =
  let cmd  = Lib1.AddExerciseNoWeight a s r
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (RemoveExercise a next)) =
  let cmd  = Lib1.RemoveExercise a
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (StartWorkout n next)) =
  let cmd  = Lib1.StartWorkout n
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (StopWorkout n next)) =
  let cmd  = Lib1.StopWorkout n
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (ShowAllWorkouts next)) =
  let cmd  = Lib1.ShowAllWorkouts
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (ShowWorkout n next)) =
  let cmd  = Lib1.ShowWorkout n
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)
runPureInterpreter st (Free (DumpExamples next)) =
  let cmd  = Lib1.Dump Lib1.Examples
      st'  = Lib3.updateState st cmd
      resp = unlines (Lib3.renderCommand st' cmd)
  in runPureInterpreter st' (next resp)