{-# LANGUAGE OverloadedStrings, RecordWildCards #-}

module FM.NetEase.JSON (
  encodeJSON
, decodeFM
, decodeRecommend
, decodePlayList
, decodePlayLists
, decodeLyrics
, decodeUserId
) where

import           Control.Monad (msum, forM)
import qualified Data.Aeson as JSON
import           Data.Aeson ((.:), (.:?))
import           Data.Aeson.Extra
import qualified Data.Aeson.Types as JSON
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import qualified Data.Vector as V
import qualified Data.Text as T
import           Text.Printf (printf)

import qualified FM.Song as Song
import           FM.NetEase.Crypto (encryptSongId)

newtype FM = FM [Song.Song]
newtype Recommend = Recommend [Song.Song]
newtype PlayList = PlayList [Song.Song]

instance JSON.FromJSON FM where
  parseJSON = onObject $ \v -> FM <$> (v .: "data" >>= parseSongList)

instance JSON.FromJSON Recommend where
  parseJSON = onObject $ \v ->  Recommend <$> (v .: "recommend" >>= parseSongList)

instance JSON.FromJSON PlayList where
  parseJSON = onObject $ \v -> PlayList <$> (v .: "result" >>= parse)
    where parse = onObject $ \v -> v .: "tracks" >>= parseSongList

parseSongList :: JSON.Value -> JSON.Parser [Song.Song]
parseSongList = onArray $ \v -> mapM parseSong (V.toList v)

parseSong :: JSON.Value -> JSON.Parser Song.Song
parseSong = onObject $ \v -> do
  -- TODO: HEAD this url to check if file really exists.
  url <- do
    urls <- forM ["hMusic", "mMusic", "lMusic"] $ \m -> do
      node <- v .:? m
      case node of
        Just node -> flip onObject node $ \v -> do
          dfsId <- v .: "dfsId" :: JSON.Parser Int
          let encId = encryptSongId (show dfsId)
          return $ Just (printf "http://m1.music.126.net/%s/%d.mp3" encId dfsId :: String)
        Nothing -> return Nothing
    case msum urls of
      Just url -> return url
      Nothing -> v .: "mp3Url"
  title <- v .: "name"
  uid <- v .: "id"
  artists <- parseArtists =<< (v .: "artists")
  album <- parseAlbum =<< (v .: "album")
  return Song.Song {..}

parseArtists :: JSON.Value -> JSON.Parser [String]
parseArtists = onArray $ \v -> forM (V.toList v) (onObject $ \v -> v .: "name")

parseAlbum :: JSON.Value -> JSON.Parser String
parseAlbum = onObject $ \v -> v .: "name"

decodeFM :: BS.ByteString -> Either String [Song.Song]
decodeFM bs = unwrap <$> JSON.eitherDecode (BL.fromStrict bs)
  where unwrap (FM xs) = xs

decodeRecommend :: BS.ByteString -> Either String [Song.Song]
decodeRecommend bs = unwrap <$> JSON.eitherDecode (BL.fromStrict bs)
  where unwrap (Recommend xs) = xs

decodePlayList :: BS.ByteString -> Either String [Song.Song]
decodePlayList bs = unwrap <$> JSON.eitherDecode (BL.fromStrict bs)
  where unwrap (PlayList xs) = xs

newtype PlayLists = PlayLists [(Int, String)]

instance JSON.FromJSON PlayLists where
  parseJSON = onObject $ \v -> PlayLists <$> (v .: "playlist" >>= parse)
    where
      parse = onArray $ \v -> mapM parsePlayLists (V.toList v)
        where
          parsePlayLists = onObject $ \v -> do
            id <- v .: "id"
            name <- v .: "name"
            return (id, name)

decodePlayLists :: BS.ByteString -> Either String [(Int, String)]
decodePlayLists bs = unwrap <$> JSON.eitherDecode (BL.fromStrict bs)
  where unwrap (PlayLists xs) = xs

newtype Lyrics = Lyrics [String]

instance JSON.FromJSON Lyrics where
  parseJSON = onObject $ \v -> v .: "lrc" >>= parse
    where parse = onObject $ \v -> Lyrics . lines . T.unpack <$> (v .: "lyric")

decodeLyrics :: BS.ByteString -> Either String [String]
decodeLyrics bs = unwrap <$> JSON.eitherDecode (BL.fromStrict bs)
  where unwrap (Lyrics lyrics) = lyrics

newtype UserId = UserId Int

instance JSON.FromJSON UserId where
  parseJSON = onObject $ \v -> v .: "account" >>= parse
    where parse = onObject $ \v -> UserId <$> (v .: "id")

decodeUserId :: BS.ByteString -> Either String Int
decodeUserId bs = unwrap <$> JSON.eitherDecode (BL.fromStrict bs)
  where unwrap (UserId id) = id
