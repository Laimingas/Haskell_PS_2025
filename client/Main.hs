{-# LANGUAGE OverloadedStrings #-}

module Main where

import WorkoutDSL
import qualified Lib1
import qualified Lib2
import qualified Lib3

import Network.HTTP.Simple
import qualified Data.ByteString.Lazy.Char8 as LBS

serverSend :: Lib1.Command -> IO String
serverSend cmd = do
  let cli = Lib2.toCliCommand cmd
  putStrLn $ "CLIENT SENDING: " ++ cli
  let req = setRequestMethod "POST"
          $ setRequestPath "/command"
          $ setRequestPort 3000
          $ setRequestHost "localhost"
          $ setRequestBodyLBS (LBS.pack cli)
          $ setRequestSecure False
          $ defaultRequest
  response <- httpLBS req
  let body = LBS.unpack (getResponseBody response)
  putStrLn $ "CLIENT GOT: " ++ body
  return body

main :: IO ()
main = do
  let dslProg = do
        r1 <- createWorkout "Routine"
                [ Lib1.AddExerciseNoWeight "Push-ups" 3 15
                , Lib1.AddExerciseNoWeight "Squats" 3 20
                ]
        r2 <- selectWorkoutOnly "Routine"
        r3 <- addExerciseWithWeight "Deadlift" 4 8 90
        r4 <- addExerciseNoWeight "Plank" 2 60
        r5 <- showAllWorkouts
        r6 <- removeExercise "Plank"
        r7 <- showAllWorkouts
        r8 <- dumpExamples
        pure $ unlines [r1,r2,r3,r4,r5,r6,r7,r8]

  putStrLn "--== SENDING COMMANDS THROUGH HTTP ==--"
  httpResult <- runHttpInterpreter serverSend dslProg
  putStrLn httpResult

  putStrLn "--== RUNNING PURE INTERPRETER WITH LOGS ==--"
  (localResult, finalState) <- runPureInterpreterWithLogger putStrLn Lib3.emptyState dslProg

  putStrLn "--== FINAL STATE ==--"
  print finalState