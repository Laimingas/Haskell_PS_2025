{-# OPTIONS_GHC -Wno-orphans #-}
{-# LANGUAGE InstanceSigs #-}
module Lib4
  ( ErrorMsg
  , Input
  , Parser
  , parseCommand
  , runParser
  , intParser
  ) where

import qualified Lib1
import Test.QuickCheck (Arbitrary(..), Gen, oneof, elements, choose)
import Control.Monad.Trans.State.Strict (State, get, put, runState, state)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT(..), runExceptT, throwE)
import Data.Char (isDigit, isSpace)
import Data.List (stripPrefix)

type ErrorMsg = String
type Input = String
type Parser = ExceptT ErrorMsg (State Input)

------------------------------------------------------------------------
-- Parsing helpers
------------------------------------------------------------------------
skipSpaces :: Parser ()
skipSpaces = do
  s <- lift get
  let s' = dropWhile isSpace s
  lift (put s')
  return ()

string :: String -> Parser ()
string str = do
  skipSpaces
  s <- lift get
  case stripPrefix str s of
    Just rest -> lift (put rest) >> return ()
    Nothing   -> throwE ("Expected: " ++ show str)

parseChar :: Parser (Maybe Char)
parseChar = do
  s <- lift get
  case s of
    []     -> return Nothing
    (c:cs) -> lift (put cs) >> return (Just c)

quotedString :: Parser String
quotedString = do
  skipSpaces
  mc <- parseChar
  case mc of
    Just '"' -> parseQuoted []
    _        -> throwE "Expected quoted string"
  where
    parseQuoted acc = do
      mc <- parseChar
      case mc of
        Nothing  -> throwE "Unterminated string"
        Just '"' -> return (reverse acc)
        Just c   -> parseQuoted (c:acc)


intParser :: Parser Int
intParser = do
  skipSpaces
  s <- lift get
  let (num, rest) = span isDigit s
  if null num then throwE "Expected integer"
  else lift (put rest) >> return (read num)

weightParser :: Parser Int
weightParser = do
  w <- intParser
  skipSpaces
  s <- lift get
  case stripPrefix "kg" s of
    Just rest -> lift (put rest) >> return w
    Nothing   -> return w -- leidžiama ir be "kg"

manyCommands :: Parser [Lib1.Command]
manyCommands = do
  skipSpaces
  s <- lift get
  if not (null s) && head s == '}' then return []
  else do
    c <- parseCommand
    cs <- manyCommands
    return (c : cs)

parseCommandList :: Parser [Lib1.Command]
parseCommandList = do
  skipSpaces
  string "{"
  cmds <- manyCommands
  skipSpaces
  string "}"
  return cmds

parseCommand :: Parser Lib1.Command
parseCommand = do
  skipSpaces
  tryParsers
    [ parseCreateWorkout
    , parseSelectWorkout
    , parseAddExerciseWithWeight
    , parseAddExerciseNoWeight
    , parseRemoveExercise
    , parseStartWorkout
    , parseStopWorkout
    , parseShowAllWorkouts
    , parseShowWorkout
    , parseDumpExamples
    ]

tryParsers :: [Parser a] -> Parser a
tryParsers []     = throwE "Unknown command"
tryParsers (p:ps) = ExceptT $ state $ \s ->
  case runState (runExceptT p) s of
    (Left _, _) -> runState (runExceptT (tryParsers ps)) s
    ok          -> ok

------------------------------------------------------------------------
-- Command parsers
------------------------------------------------------------------------

-- <command> ::= "create workout" <quoted_string> "{" <command_list> "}"
parseCreateWorkout :: Parser Lib1.Command
parseCreateWorkout = do
  string "create workout"
  name <- quotedString
  clist <- parseCommandList
  return $ Lib1.CreateWorkout name clist

-- <command> ::= "select workout" <quoted_string> "{" <command_list> "}"
parseSelectWorkout :: Parser Lib1.Command
parseSelectWorkout = do
  string "select workout"
  name <- quotedString
  clist <- parseCommandList
  return $ Lib1.SelectWorkout name clist

-- <command> ::= "add exercise" <quoted_string> <integer> <integer> <weight>
parseAddExerciseWithWeight :: Parser Lib1.Command
parseAddExerciseWithWeight = do
  string "add exercise"
  name <- quotedString
  sets <- intParser
  reps <- intParser
  weight <- weightParser
  return $ Lib1.AddExerciseWithWeight name sets reps weight

-- <command> ::= "add exercise" <quoted_string> <integer> <integer>
parseAddExerciseNoWeight :: Parser Lib1.Command
parseAddExerciseNoWeight = do
  string "add exercise"
  name <- quotedString
  sets <- intParser
  reps <- intParser
  skipSpaces
  s <- lift get
  if take 2 s == "kg"
     then throwE "Ambiguous: Looks like add exercise with weight, not NoWeight"
     else return $ Lib1.AddExerciseNoWeight name sets reps

-- <command> ::= "remove exercise" <quoted_string>
parseRemoveExercise :: Parser Lib1.Command
parseRemoveExercise = do
  string "remove exercise"
  name <- quotedString
  return $ Lib1.RemoveExercise name

-- <command> ::= "start" <quoted_string>
parseStartWorkout :: Parser Lib1.Command
parseStartWorkout = do
  string "start"
  name <- quotedString
  return $ Lib1.StartWorkout name

-- <command> ::= "stop" <quoted_string>
parseStopWorkout :: Parser Lib1.Command
parseStopWorkout = do
  string "stop"
  name <- quotedString
  return $ Lib1.StopWorkout name

-- <command> ::= "show all workouts"
parseShowAllWorkouts :: Parser Lib1.Command
parseShowAllWorkouts = do
  string "show all workouts"
  return $ Lib1.ShowAllWorkouts

-- <command> ::= "show workout" <quoted_string>
parseShowWorkout :: Parser Lib1.Command
parseShowWorkout = do
  string "show workout"
  name <- quotedString
  return $ Lib1.ShowWorkout name

-- <command> ::= "dump examples"
parseDumpExamples :: Parser Lib1.Command
parseDumpExamples = do
  string "dump examples"
  return $ Lib1.Dump Lib1.Examples

instance Arbitrary Lib1.Command where
  arbitrary :: Gen Lib1.Command
  arbitrary =
    let genStr    = elements ["Push-ups", "Squats", "Bench Press", "Pull-ups", "Deadlift", "Leg Day", "Morning Routine", "Upper Body Blast", "Lunges"]
        genSets   = choose (1,10)
        genReps   = choose (1,30)
        genWeight = choose (0,200)
    in oneof
       [ Lib1.CreateWorkout <$> genStr <*> arbCmds
       , Lib1.SelectWorkout <$> genStr <*> arbCmds
       , Lib1.AddExerciseWithWeight <$> genStr <*> genSets <*> genReps <*> genWeight
       , Lib1.AddExerciseNoWeight <$> genStr <*> genSets <*> genReps
       , Lib1.RemoveExercise <$> genStr
       , Lib1.StartWorkout <$> genStr
       , Lib1.StopWorkout <$> genStr
       , pure Lib1.ShowAllWorkouts
       , Lib1.ShowWorkout <$> genStr
       , pure (Lib1.Dump Lib1.Examples)
       ]
    where
      arbCmds = do n <- choose (0,2)
                   sequenceA (replicate n arbitrary)


runParser :: Parser a -> String -> Either ErrorMsg (a, Input)
runParser p input =
  case runState (runExceptT p) input of
    (Left err, _)   -> Left err
    (Right x, rest) -> Right (x, rest)