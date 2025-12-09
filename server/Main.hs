{-# LANGUAGE OverloadedStrings #-}
module Main where

-- Simple Scotty-based HTTP server for the Workout Planner.
-- Behaviour:
--  - Accepts POST /command where the request body is a CLI-style command string.
--  - Parses the command using Lib4.runParser.
--  - Updates the in-memory state (TVar) with Lib3.updateState.
--  - Periodically persists state to file using the storage channel loop.
--
-- Shutdown ordering:
--  - perform a synchronous save first (Lib3.save) while the storage loop is still running,
--  - then cancel background workers (periodic save, storage loop),

import Web.Scotty
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE
import qualified Lib1
import qualified Lib2
import qualified Lib3
import qualified Lib4

import Control.Concurrent.STM
import Control.Monad.IO.Class (liftIO)
import System.Exit (ExitCode(ExitSuccess))
import Control.Concurrent (forkIO, threadDelay)
import System.Posix.Signals (installHandler, Handler(..), sigINT, sigTERM)
import Control.Concurrent.Chan
import Network.HTTP.Types.Status (status400)
import System.Posix.Process (exitImmediately)
import Control.Concurrent.Async (Async, async, cancel)

main :: IO ()
main = do
  -- Storage & in-memory app state (as TVar)
  stVar <- newTVarIO Lib3.emptyState

  -- Storage channel background thread for save/load
  storageChan <- newChan
  storageAsync <- async $ Lib3.storageOpLoop storageChan

  -- load saved state on startup (synchronous)
  _ <- Lib3.load storageChan stVar

  -- periodic background saver
  saveAsync <- async $ foreverSave storageChan stVar

  -- Clean shutdown handler (persist data)
  let handleShutdown = do
        putStrLn "Shutting down, saving state..."
        -- ensure we save while storage loop is alive
        _ <- Lib3.save storageChan stVar
        -- then cancel the background jobs
        cancel saveAsync
        cancel storageAsync
        -- exit immediately
        exitImmediately ExitSuccess

  _ <- installHandler sigINT  (Catch handleShutdown) Nothing
  _ <- installHandler sigTERM (Catch handleShutdown) Nothing

  putStrLn "Workout Planner HTTP server started on :3000"
  scotty 3000 $ do
    get "/" $ do
      html $ "<h1>Welcome to Workout Planner Server!</h1><p>POST /command for API</p>"

    -- POST /command: parse, update state, and return renderCommand output
    post "/command" $ do
      bodyText <- body >>= (return . TL.unpack . TLE.decodeUtf8)
      let res = Lib4.runParser Lib4.parseCommand bodyText
      case res of
        Left err -> do
          status status400
          text $ TL.pack $ "Parser Error: " ++ err
        Right (cmd, _) -> do
          newState <- liftIO $ atomically $ do
            s <- readTVar stVar
            let s' = Lib3.updateState s cmd
            writeTVar stVar s'
            return s'
          let cliOut = Lib3.renderCommand newState cmd
              resp = unlines cliOut
          text $ TL.pack resp


-- Periodic saver implementation: calls Lib3.save every 20 seconds
foreverSave :: Chan Lib3.StorageOp -> TVar Lib3.State -> IO ()
foreverSave ch st = do
  let seconds = 20
  let loop = do
        threadDelay (seconds * 1000000)
        _ <- Lib3.save ch st
        loop
  loop