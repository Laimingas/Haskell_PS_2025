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
  let req = setRequestMethod "POST"
          $ setRequestPath "/command"
          $ setRequestPort 3000
          $ setRequestHost "localhost"
          $ setRequestBodyLBS (LBS.pack cli)
          $ setRequestSecure False
          $ defaultRequest
  response <- httpLBS req
  return $ LBS.unpack (getResponseBody response)

main :: IO ()
main = do
  let dslProg = do
        r1 <- createWorkout "Routine"
                [ Lib1.AddExerciseNoWeight "Push-ups" 3 15
                , Lib1.AddExerciseNoWeight "Squats" 3 20
                ]
        r2 <- addExerciseWithWeight "Deadlift" 4 8 90
        r3 <- addExerciseNoWeight "Plank" 2 60
        r4 <- showAllWorkouts
        r5 <- removeExercise "Plank"
        r6 <- showAllWorkouts
        r7 <- showWorkout "Evening Routine"
        r8 <- dumpExamples
        pure $ unlines [r1,r2,r3,r4,r5,r6,r7,r8]

  putStrLn "--== SIUNCIAM KOMANDAS PER HTTP ==--"
  httpResult <- runHttpInterpreter serverSend dslProg
  putStrLn httpResult

  putStrLn "--== TESTUOJAM LOKALIAI (PURE interpreter) ==--"
  let (localResult, _finalState) = runPureInterpreter Lib3.emptyState dslProg
  putStrLn localResult