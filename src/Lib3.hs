{-# OPTIONS_GHC -Wno-orphans #-}
module Lib3(
    emptyState, State(..), execute, load, save, storageOpLoop, StorageOp, Parser(..), parseCommand) where

import qualified Lib1
import Control.Applicative (Alternative(..), optional)
import Data.Char (isDigit, isSpace)

import Control.Concurrent.STM.TVar(TVar)
import Control.Concurrent (Chan, readChan)
import GHC.Conc (par)

newtype Parser a = Parser {
    runParser :: String -> Either String (a, String)
}

instance Functor Parser where
    fmap f (Parser p) = Parser $ \input -> case p input of
        Left err -> Left err
        Right (a, rest) -> Right (f a, rest)

instance Applicative Parser where
    pure a = Parser $ \input -> Right (a, input)
    (Parser pf) <*> (Parser pa) = Parser $ \input -> case pf input of
        Left err -> Left err
        Right (f, rest1) -> case pa rest1 of
            Left err -> Left err
            Right (a, rest2) -> Right (f a, rest2)

instance Alternative Parser where
    empty = Parser $ \_ -> Left "empty"
    (Parser p1) <|> (Parser p2) = Parser $ \input -> case p1 input of
        Left _ -> p2 input
        Right res -> Right res

trim :: String -> String
trim = dropWhile isSpace

satisfy :: (Char -> Bool) -> Parser Char
satisfy predicate = Parser $ \input ->
    case trim input of
        (c:rest) | predicate c -> Right (c, rest)
        _ -> Left "satisfy: no match"

char :: Char -> Parser Char
char expected = satisfy (== expected)

string :: String -> Parser String
string expected = Parser $ \input ->
    let trimmed = trim input
    in if take (length expected) trimmed == expected
        then Right (expected, drop (length expected) trimmed)
        else Left $ "Expected string: " ++ expected

symbol :: String -> Parser ()
symbol s = () <$ string s

keyword :: String -> Parser ()
keyword = symbol

number :: Parser Int
number = Parser $ \input ->
    let (ds, rest) = span isDigit (trim input)
    in if null ds then Left "Expected number" else Right (read ds, rest)

quotedString :: Parser String
quotedString = Parser $ \input ->
    case trim input of
        ('"':xs) -> collect xs ""
        _ -> Left "Expected quoted string"
  where
    collect [] _ = Left "Unterminated string"
    collect ('"':rest) acc = Right (reverse acc, rest)
    collect (c:rest) acc = collect rest (c:acc)

-- Parse weight with optional “kg”
weightP :: Parser Int
weightP = Parser $ \input -> 
    case runParser number input of
        Left err -> Left err
        Right (n, rest) ->
            let rest' = trim rest
            in if take 2 rest' == "kg"
                then Right (n, drop 2 rest')
                else Right (n, rest') -- weight is optional

parseCommandsInBrackets :: Parser [Lib1.Command]
parseCommandsInBrackets = Parser $ \input -> 
  case runParser (symbol "{") input of
    Left _ -> Right ([], input)
    Right (_, rest) -> collect rest []
  where
    collect inp acc =
      case runParser (symbol "}") inp of
        Right (_, rest2) -> Right (reverse acc, rest2)
        Left _ -> case runParser parseCommand inp of
          Left err -> Left err
          Right (cmd, restCmd) -> 
            let restCmd' = trim restCmd
                restAfterSpace =
                  case restCmd' of
                    (' ':restSpace) -> trim restSpace
                    _ -> restCmd'
            in collect restAfterSpace (cmd : acc)

parseCreateWorkout :: Parser Lib1.Command
parseCreateWorkout = 
  Lib1.CreateWorkout
    <$> (keyword "create workout" *> quotedString)
    <*> parseCommandsInBrackets

parseSelectWorkout :: Parser Lib1.Command
parseSelectWorkout =
  Lib1.SelectWorkout
    <$> (keyword "select workout" *> quotedString)
    <*> parseCommandsInBrackets

parseAddExerciseWithWeight :: Parser Lib1.Command
parseAddExerciseWithWeight =
  Lib1.AddExerciseWithWeight
    <$> (keyword "add exercise" *> quotedString)
    <*> number
    <*> number
    <*> weightP

parseAddExerciseNoWeight :: Parser Lib1.Command
parseAddExerciseNoWeight =
  Lib1.AddExerciseNoWeight
    <$> (keyword "add exercise" *> quotedString)
    <*> number
    <*> number

parseRemoveExercise :: Parser Lib1.Command
parseRemoveExercise =
  Lib1.RemoveExercise
    <$> (keyword "remove exercise" *> quotedString)

parseStartWorkout :: Parser Lib1.Command
parseStartWorkout =
  Lib1.StartWorkout
    <$> (keyword "start" *> quotedString)

parseStopWorkout :: Parser Lib1.Command
parseStopWorkout =
  Lib1.StopWorkout
    <$> (keyword "stop" *> quotedString)

parseShowWorkout :: Parser Lib1.Command
parseShowWorkout =
  Lib1.ShowWorkout
    <$> (keyword "show workout" *> quotedString)

parseShowAllWorkouts :: Parser Lib1.Command
parseShowAllWorkouts =
  Lib1.ShowAllWorkouts <$ keyword "show all workouts"

parseDumpExamples :: Parser Lib1.Command
parseDumpExamples =
  Lib1.Dump Lib1.Examples <$ keyword "dump examples"

-- | Parses user's input.
-- Yes, this is pretty much the same parser as in Lib2
-- but with a bit different requirements:
-- 1) It must implement Functor, Applicative and Alternative
-- 2) It must NOT implement Monad, no do-notations
-- 3) pmap with andN become <$> <*>
-- 4) orElse becomes <|>
-- 5) many and many1 become many and some
-- Yes, it will be mostly a copy-paste but an easy one
-- if Lib2 was implemented correctly.
parseCommand :: Parser Lib1.Command
parseCommand = Parser $ \input -> 
  runParser (
      parseCreateWorkout
  <|> parseSelectWorkout
  <|> parseAddExerciseWithWeight
  <|> parseAddExerciseNoWeight
  <|> parseRemoveExercise
  <|> parseStartWorkout
  <|> parseStopWorkout
  <|> parseShowAllWorkouts
  <|> parseShowWorkout
  <|> parseDumpExamples
  ) input

-- | You can change the type to whatever needed. If your domain
-- does not have any state you have to make it up.
newtype State = State ()

-- Fix this accordingly
emptyState :: State
emptyState = State()

-- | Business/domain logic happens here.
-- This function makes your program actually usefull.
-- You may print if you want to print, you
-- may mutate state if needed but there must be
-- SINGLE atomically call in the function
-- You do not want to write/read files here.
execute :: TVar State -> Lib1.Command -> IO ()
execute _ _ = error "Implement me 1"

data StorageOp = Save String (Chan ()) | Load (Chan String)
-- | This function is started from main
-- in a dedicated thread. It must be used to control
-- file access in a synchronized manner: read requests
-- from chan, do the IO operations needed and respond
-- to a channel provided in a request. It must run forever.
-- Modify as needed.
storageOpLoop :: Chan StorageOp -> IO ()
storageOpLoop c = do
  _ <- readChan c
  return $ error "Implement me 2"

-- | This function will be called periodically
-- and on programs' exit. File writes must be performed
-- through `Chan StorageOp`.
save :: Chan StorageOp -> TVar State -> IO (Either String ())
save _ _ = return $ Left "Implement me 3"

-- | This function will be called on program start
-- File reads must be performed through `Chan StorageOp`
load :: Chan StorageOp -> TVar State -> IO (Either String ())
load _ _ = return $ Left "Implement me 4"
