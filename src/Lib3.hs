{-# OPTIONS_GHC -Wno-orphans #-}
module Lib3(
    emptyState, State(..), execute, load, save, storageOpLoop, StorageOp, Parser(..), parseCommand, updateState, renderCommand) where

import qualified Lib1
import Control.Applicative (Alternative(..), many)
import Data.Char (isDigit, isSpace)

import Control.Concurrent.STM.TVar(TVar, readTVar, writeTVar, readTVarIO)
import Control.Concurrent (Chan, newChan, readChan, writeChan)
import Control.Monad (forever)
import Control.Monad.STM (atomically)
import System.Directory (doesFileExist)
import qualified Lib2
import Data.Maybe (isJust)

-- =====================
-- Parser
-- =====================

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
                else Right (n, rest')

parseCommandsInBrackets :: Parser [Lib1.Command]
parseCommandsInBrackets =
  (symbol "{" *> many parseCommand <* symbol "}") <|> pure []

-- <command> ::= "create workout" <workout_name> { <command_list> }
parseCreateWorkout :: Parser Lib1.Command
parseCreateWorkout =
  Lib1.CreateWorkout
    <$> (keyword "create workout" *> quotedString)
    <*> parseCommandsInBrackets

-- <command> ::= "select workout" <workout_name> { <command_list> }
parseSelectWorkout :: Parser Lib1.Command
parseSelectWorkout =
  Lib1.SelectWorkout
    <$> (keyword "select workout" *> quotedString)
    <*> parseCommandsInBrackets

-- <command> ::= "add exercise" <exercise_name> <sets> <reps> <weight>
parseAddExerciseWithWeight :: Parser Lib1.Command
parseAddExerciseWithWeight =
  Lib1.AddExerciseWithWeight
    <$> (keyword "add exercise" *> quotedString)
    <*> number
    <*> number
    <*> weightP

-- <command> ::= "add exercise" <exercise_name> <sets> <reps>
parseAddExerciseNoWeight :: Parser Lib1.Command
parseAddExerciseNoWeight =
  Lib1.AddExerciseNoWeight
    <$> (keyword "add exercise" *> quotedString)
    <*> number
    <*> number

-- <command> ::= "remove exercise" <exercise_name>
parseRemoveExercise :: Parser Lib1.Command
parseRemoveExercise =
  Lib1.RemoveExercise
    <$> (keyword "remove exercise" *> quotedString)

-- <command> ::= "start" <workout_name>
parseStartWorkout :: Parser Lib1.Command
parseStartWorkout =
  Lib1.StartWorkout
    <$> (keyword "start" *> quotedString)

-- <command> ::= "stop" <workout_name>
parseStopWorkout :: Parser Lib1.Command
parseStopWorkout =
  Lib1.StopWorkout
    <$> (keyword "stop" *> quotedString)

-- <command> ::= "show workout" <workout_name>
parseShowWorkout :: Parser Lib1.Command
parseShowWorkout =
  Lib1.ShowWorkout
    <$> (keyword "show workout" *> quotedString)

-- <command> ::= "show all workouts"
parseShowAllWorkouts :: Parser Lib1.Command
parseShowAllWorkouts =
  Lib1.ShowAllWorkouts <$ keyword "show all workouts"

-- <command> ::= "dump examples"
parseDumpExamples :: Parser Lib1.Command
parseDumpExamples =
  Lib1.Dump Lib1.Examples <$ keyword "dump examples"

parseCommand :: Parser Lib1.Command
parseCommand =
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

-- =====================
-- State and Logic
-- =====================

data Excercise = ExerciseNoWeight String Int Int
  | ExerciseWithWeight String Int Int Int
 deriving (Show, Eq)

data Workout = Workout {
    wname       :: String,
    exercises   :: [Excercise],
    subWorkouts :: [Workout]
} deriving (Show, Eq)

data State = State {
    workouts :: [Workout],
    currentWorkoutName :: Maybe String
} deriving (Show, Eq)

emptyState :: State
emptyState = State [] Nothing

collectExercises :: [Lib1.Command] -> [Excercise]
collectExercises = foldr (\c acc -> case c of
    Lib1.AddExerciseNoWeight n s r   -> ExerciseNoWeight n s r : acc
    Lib1.AddExerciseWithWeight n s r w -> ExerciseWithWeight n s r w : acc
    _ -> acc) []

collectSubWorkouts :: [Lib1.Command] -> [Workout]
collectSubWorkouts = foldr (\c acc -> case c of
    Lib1.CreateWorkout n subcmds -> buildWorkout n subcmds : acc
    _ -> acc) []

-- buildWorkout is a helper function used for processing CreateWorkout
buildWorkout :: String -> [Lib1.Command] -> Workout
buildWorkout n cmds = Workout n (collectExercises cmds) (collectSubWorkouts cmds)

-- Helper function for naming an exercise
isExerciseNamed :: String -> Excercise -> Bool
isExerciseNamed exName (ExerciseNoWeight n _ _)      = exName == n
isExerciseNamed exName (ExerciseWithWeight n _ _ _)  = exName == n

-- Helper function to find a workout by name 
findWorkout :: String -> [Workout] -> Maybe Workout
findWorkout _ [] = Nothing
findWorkout target (w@(Workout name _ subs) : rest)
  | target == name = Just w
  | otherwise      = findWorkout target subs <|> findWorkout target rest

-- Helper function to find/update a workout by name 
modifyWorkout :: String -> (Workout -> Workout) -> [Workout] -> [Workout]
modifyWorkout _ _ [] = []
modifyWorkout target f (w@(Workout name exs subs) : rest)
  | target == name = f w : rest
  | otherwise      =
    let
      modifiedSubs = modifyWorkout target f subs
    in
      if modifiedSubs /= subs
        then w { subWorkouts = modifiedSubs } : rest
        else w : modifyWorkout target f rest


updateState :: State -> Lib1.Command -> State
updateState (State ws cw) (Lib1.CreateWorkout name cmds) =
  if isJust (findWorkout name ws)
    then State ws cw
    else State (ws ++ [buildWorkout name cmds]) cw

updateState state (Lib1.SelectWorkout name cmds) =
    state {
      workouts = modifyWorkout name (addContentToWorkout cmds) (workouts state),
      currentWorkoutName = Just name
    }
  where
    addContentToWorkout cmds w = w {
      exercises = exercises w ++ collectExercises cmds,
      subWorkouts = subWorkouts w ++ collectSubWorkouts cmds
    }

updateState state@(State ws (Just cwName)) (Lib1.AddExerciseNoWeight name sets reps) =
  state { workouts = modifyWorkout cwName (addExercise (ExerciseNoWeight name sets reps)) ws }
  where addExercise ex w = w { exercises = exercises w ++ [ex] }

updateState state@(State ws (Just cwName)) (Lib1.AddExerciseWithWeight name sets reps weight) =
  state { workouts = modifyWorkout cwName (addExercise (ExerciseWithWeight name sets reps weight)) ws }
  where addExercise ex w = w { exercises = exercises w ++ [ex] }

updateState state@(State ws (Just cwName)) (Lib1.RemoveExercise name) =
  state { workouts = modifyWorkout cwName removeExercise ws }
  where
    removeExercise w = w { exercises = filter (not . isExerciseNamed name) (exercises w) }

updateState state _ = state

-- =====================
-- Rendering
-- =====================

renderExercise :: Excercise -> [String]
renderExercise (ExerciseNoWeight n s r) =
  ["  " ++ n ++ ": " ++ show s ++ " sets of " ++ show r ++ " reps"]
renderExercise (ExerciseWithWeight n s r w) =
  ["  " ++ n ++ ": " ++ show s ++ " sets of " ++ show r ++ " reps with " ++ show w ++ "kg"]

renderWorkout :: Workout -> [String]
renderWorkout (Workout name exs subs) =
  ("Workout: " ++ name) : concatMap renderExercise exs ++ concatMap renderWorkout subs

renderCommand :: State -> Lib1.Command -> [String]
renderCommand st (Lib1.Dump Lib1.Examples) =
  "Examples:" : map Lib2.toCliCommand Lib1.examples

renderCommand st Lib1.ShowAllWorkouts =
  map wname (workouts st)

renderCommand st (Lib1.ShowWorkout name) =
  case findWorkout name (workouts st) of
    Just w  -> renderWorkout w
    Nothing -> ["Workout \"" ++ name ++ "\" not found."]

renderCommand st (Lib1.CreateWorkout name _) =
  ["Workout \"" ++ name ++ "\" created."]

renderCommand st (Lib1.SelectWorkout name _) =
  ["Selected workout \"" ++ name ++ "\"."]

renderCommand st (Lib1.AddExerciseNoWeight name sets reps) =
  ["Added exercise \"" ++ name ++ "\" (" ++ show sets ++ "x" ++ show reps ++ ")."]

renderCommand st (Lib1.AddExerciseWithWeight name sets reps w) =
  ["Added exercise \"" ++ name ++ "\" (" ++ show sets ++ "x" ++ show reps ++ ") with " ++ show w ++ "kg."]

renderCommand st (Lib1.RemoveExercise name) =
  ["Removed exercise \"" ++ name ++ "\" (if it existed)."]

renderCommand st (Lib1.StartWorkout name) =
  ["Started workout \"" ++ name ++ "\"."]

renderCommand st (Lib1.StopWorkout name) =
  ["Stopped workout \"" ++ name ++ "\"."]

renderCommand _ cmd = ["Parsed as " ++ show cmd]


execute :: TVar State -> Lib1.Command -> IO ()
execute tvar cmd = do
  newState <- atomically $ do
    state <- readTVar tvar
    let newState = updateState state cmd
    writeTVar tvar newState
    return newState

  let outLines = renderCommand newState cmd
  mapM_ putStrLn outLines

-- =====================
-- Storage Handling
-- =====================

data StorageOp = Save String (Chan ()) | Load (Chan String)

storageFile :: FilePath
storageFile = "storage.txt"

storageOpLoop :: Chan StorageOp -> IO ()
storageOpLoop chan = forever $ do
  op <- readChan chan
  case op of
    Save content respChan -> do
      writeFile storageFile content
      writeChan respChan ()
    Load reply -> do
      exists <- doesFileExist storageFile
      if exists then do
        content <- readFile storageFile
        writeChan reply content
      else writeChan reply ""

serializeState :: State -> String
serializeState (State ws _) =
  unlines $ concatMap serializeWorkout ws

serializeWorkout :: Workout -> [String]
serializeWorkout (Workout name exs subs) =
    let
        exerciseLines = map serializeExercise exs
        subWorkoutLines = concatMap serializeWorkout subs
        innerLines = exerciseLines ++ subWorkoutLines
        createLine = "create workout \"" ++ name ++ "\""
    in
        if null innerLines
            then [createLine]
            else [createLine, "{"] ++ innerLines ++ ["}"]


serializeExercise :: Excercise -> String
serializeExercise (ExerciseNoWeight n s r) = "add exercise \"" ++ n ++ "\" " ++ show s ++ " " ++ show r
serializeExercise (ExerciseWithWeight n s r w) = "add exercise \"" ++ n ++ "\" " ++ show s ++ " " ++ show r ++ " " ++ show w ++ "kg"

save :: Chan StorageOp -> TVar State -> IO (Either String ())
save chan tvar = do
  state <- readTVarIO tvar
  let content = serializeState state
  respChan <- newChan
  writeChan chan (Save content respChan)
  _ <- readChan respChan
  return $ Right ()

load :: Chan StorageOp -> TVar State -> IO (Either String ())
load chan tvar = do
  replyChan <- newChan
  writeChan chan (Load replyChan)
  content <- readChan replyChan
  case runParser (many parseCommand) content of
    Left err -> return $ Left $ "Failed to parse state file: " ++ err
    Right (cmds, rest) ->
      if null (trim rest) then do
        let newState = foldl updateState emptyState cmds
        atomically $ writeTVar tvar newState
        return $ Right ()
      else
        return $ Left $ "Failed to parse entire state file."