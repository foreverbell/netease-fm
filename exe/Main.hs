module Main where

import           Control.Monad.IO.Class
import           Control.Monad.Trans.Cont
import           System.Directory (getHomeDirectory, createDirectoryIfMissing)

import           FM.FM
import qualified FM.NetEase as NetEase

import qualified UI.Black as Black
import qualified UI.Login as Login
import qualified UI.Menu as Menu
import qualified UI.Player as Player

import           SessionManager
import           Types

getCache :: IO FilePath
getCache = do
  root <- (++ "/.fm") <$> getHomeDirectory
  createDirectoryIfMissing True root
  let cache = root ++ "/cache"
  createDirectoryIfMissing True cache
  return cache

main :: IO ()
main = do
  sessionManager <- newSessionManager
  cache <- initCache =<< getCache
  evalContT $ do
    source <- Menu.menuSelection [ NetEaseFM, NetEasePublicFM, NetEaseDailyRecommendation, NetEasePlayLists, LocalCache ] Nothing "播放源"
    session <- Login.login "登入" source sessionManager cache
    case source of
      NetEasePlayLists -> do
        playLists <- liftIO $ Black.black Nothing (runSessionOnly session NetEase.fetchPlayLists) return
        source <- Menu.menuSelection [ NetEasePlayList id title | (id, title) <- playLists ] Nothing (show1 NetEasePlayLists)
        Player.musicPlayer source session cache
      _ -> Player.musicPlayer source session cache
  Black.black (Just "缓存队列中有任务，缓存完毕后自动退出。") (waitCaching cache) return
