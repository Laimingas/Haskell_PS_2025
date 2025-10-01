{-# LANGUAGE InstanceSigs #-}
{-# OPTIONS_GHC -Wno-orphans #-}
module Lib2
  ( parseCommand
  , ToCliCommand(..)
  , process
  ) where

import qualified Lib1
import Data.Char (isDigit, isSpace)

type ErrorMsg = String
type Parser a = String -> Either ErrorMsg (a, String)

trim :: String -> String
trim = dropWhile isSpace

orElse :: Parser a -> Parser a -> Parser a
orElse p q input = case p input of
  Right res -> Right res
  Left _ -> q input

and2 :: Parser a -> Parser b -> Parser (a,b)
and2 p q input = do
  (a, rest1) <- p input
  (b, rest2) <- q (trim rest1)
  Right ((a,b), rest2)

and3 :: Parser a -> Parser b -> Parser c -> Parser (a,b,c)
and3 p q r input = do
  ((a,b), rest1) <- and2 p q input
  (c, rest2) <- r (trim rest1)
  Right ((a,b,c), rest2)

and4 :: Parser a -> Parser b -> Parser c -> Parser d -> Parser (a,b,c,d)
and4 p q r s input = do
  ((a,b,c), rest1) <- and3 p q r input
  (d, rest2) <- s (trim rest1)
  Right ((a,b,c,d), rest2)

mapP :: Parser a -> (a -> b) -> Parser b
mapP p f input = do
  (a, rest) <- p input
  Right (f a, rest)

ignore :: Parser a -> Parser b -> Parser b
ignore p q = mapP (and2 p q) snd

number :: Parser Int
number input =
  let (ds, rest) = span isDigit (trim input)
  in if null ds then Left "Expected number" else Right (read ds, rest)

quotedString :: Parser String
quotedString input =
  case trim input of
    ('"':xs) -> collect xs ""
    _ -> Left "Expected quoted string"
  where
    collect [] _ = Left "Unterminated string"
    collect ('"':rest) acc = Right (reverse acc, rest)
    collect (c:cs) acc = collect cs (c:acc)

keyword :: String -> Parser ()
keyword kw input =
  let s = trim input
  in if kw == take (length kw) s
        then Right ((), drop (length kw) s)
        else Left $ "Expected keyword: " ++ kw

symbol :: String -> Parser ()
symbol s input =
  let s' = trim input
  in if s == take (length s) s'
        then Right ((), drop (length s) s')
        else Left $ "Expected symbol: " ++ s

weightP :: Parser Int
weightP input = do
  (n, rest) <- number input
  let rest' = trim rest
  if take 2 rest' == "kg"
     then Right (n, drop 2 rest')
     else Right (n, rest') -- weight is optional

parseCommandList :: Parser [Lib1.Command]
parseCommandList input = do
  (_, rest) <- symbol "{" input
  parseCommands rest
  where
    parseCommands s =
      let s' = trim s
      in case s' of
           ('}':rest') -> Right ([], rest')
           _ -> do
             (cmd, rest1) <- parseCommand s'
             (cmds, rest2) <- parseCommands (trim rest1)
             Right (cmd:cmds, rest2)

parseCreateWorkout :: Parser Lib1.Command
parseCreateWorkout =
  mapP (and2 (ignore (keyword "create workout") quotedString) parseCommandList)
       (\(name, cmds) -> Lib1.CreateWorkout name cmds)

parseSelectWorkout :: Parser Lib1.Command
parseSelectWorkout =
  mapP (and2 (ignore (keyword "select workout") quotedString) parseCommandList)
       (\(name, cmds) -> Lib1.SelectWorkout name cmds)

parseAddExerciseWithWeight :: Parser Lib1.Command
parseAddExerciseWithWeight =
  mapP (and4 (ignore (keyword "add exercise") quotedString) number number weightP)
       (\(name, sets, reps, w) -> Lib1.AddExerciseWithWeight name sets reps w)

parseAddExerciseNoWeight :: Parser Lib1.Command
parseAddExerciseNoWeight =
  mapP (and3 (ignore (keyword "add exercise") quotedString) number number)
       (\(name, sets, reps) -> Lib1.AddExerciseNoWeight name sets reps)

parseRemoveExercise :: Parser Lib1.Command
parseRemoveExercise =
  mapP (ignore (keyword "remove exercise") quotedString)
       (\name -> Lib1.RemoveExercise name)

parseStartWorkout :: Parser Lib1.Command
parseStartWorkout =
  mapP (ignore (keyword "start") quotedString)
       (\name -> Lib1.StartWorkout name)

parseStopWorkout :: Parser Lib1.Command
parseStopWorkout =
  mapP (ignore (keyword "stop") quotedString)
       (\name -> Lib1.StopWorkout name)

parseShowAllWorkouts :: Parser Lib1.Command
parseShowAllWorkouts =
  mapP (keyword "show all workouts") (const Lib1.ShowAllWorkouts)

parseShowWorkout :: Parser Lib1.Command
parseShowWorkout =
  mapP (ignore (keyword "show workout") quotedString)
       (\name -> Lib1.ShowWorkout name)

parseDumpExamples :: Parser Lib1.Command
parseDumpExamples =
  mapP (keyword "dump examples") (const (Lib1.Dump Lib1.Examples))

parseCommand :: Parser Lib1.Command
parseCommand =
      parseCreateWorkout
  `orElse` parseSelectWorkout
  `orElse` parseAddExerciseWithWeight
  `orElse` parseAddExerciseNoWeight
  `orElse` parseRemoveExercise
  `orElse` parseStartWorkout
  `orElse` parseStopWorkout
  `orElse` parseShowAllWorkouts
  `orElse` parseShowWorkout
  `orElse` parseDumpExamples

process :: Lib1.Command -> [String]
process (Lib1.Dump Lib1.Examples) = "Examples:" : map toCliCommand Lib1.examples
process c = ["Parsed as " ++ show c]

class ToCliCommand a where
  toCliCommand :: a -> String

instance ToCliCommand Lib1.Command where
  toCliCommand cmd = case cmd of
    Lib1.CreateWorkout name cmds -> "create workout \"" ++ name ++ "\" { " ++ unwords (map toCliCommand cmds) ++ " }"
    Lib1.SelectWorkout name cmds -> "select workout \"" ++ name ++ "\" { " ++ unwords (map toCliCommand cmds) ++ " }"
    Lib1.AddExerciseWithWeight name s r w -> "add exercise \"" ++ name ++ "\" " ++ show s ++ " " ++ show r ++ " " ++ show w ++ "kg"
    Lib1.AddExerciseNoWeight name s r -> "add exercise \"" ++ name ++ "\" " ++ show s ++ " " ++ show r
    Lib1.RemoveExercise name -> "remove exercise \"" ++ name ++ "\""
    Lib1.StartWorkout name -> "start \"" ++ name ++ "\""
    Lib1.StopWorkout name -> "stop \"" ++ name ++ "\""
    Lib1.ShowAllWorkouts -> "show all workouts"
    Lib1.ShowWorkout name -> "show workout \"" ++ name ++ "\""
    Lib1.Dump _ -> "dump examples"

instance Eq Lib1.Command where
  (Lib1.CreateWorkout n1 cs1) == (Lib1.CreateWorkout n2 cs2) = n1==n2 && cs1==cs2
  (Lib1.SelectWorkout n1 cs1) == (Lib1.SelectWorkout n2 cs2) = n1==n2 && cs1==cs2
  (Lib1.AddExerciseWithWeight n1 s1 r1 w1) == (Lib1.AddExerciseWithWeight n2 s2 r2 w2) = n1==n2 && s1==s2 && r1==r2 && w1==w2
  (Lib1.AddExerciseNoWeight n1 s1 r1) == (Lib1.AddExerciseNoWeight n2 s2 r2) = n1==n2 && s1==s2 && r1==r2
  (Lib1.RemoveExercise n1) == (Lib1.RemoveExercise n2) = n1==n2
  (Lib1.StartWorkout n1) == (Lib1.StartWorkout n2) = n1==n2
  (Lib1.StopWorkout n1) == (Lib1.StopWorkout n2) = n1==n2
  Lib1.ShowAllWorkouts == Lib1.ShowAllWorkouts = True
  (Lib1.ShowWorkout n1) == (Lib1.ShowWorkout n2) = n1==n2
  (Lib1.Dump _) == (Lib1.Dump _) = True
  _ == _ = False
