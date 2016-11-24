{-|
  This module defines various utility functions used across the 
  Network.Haskoin modules.
-}
module Network.Haskoin.Util
( -- * ByteString helpers
  toStrictBS
, toLazyBS
, stringToBS
, bsToString
, bsToInteger
, integerToBS
, bsToHex
, hexToBS

  -- * Data.Binary helpers
, encode'
, decode'
, runPut'
, runGet'
, decodeOrFail'
, runGetOrFail'
, fromDecode
, fromRunGet
, decodeToEither
, decodeToMaybe
, isolate

  -- * Maybe and Either monad helpers
, isLeft
, isRight
, fromRight
, fromLeft
, eitherToMaybe
, maybeToEither

  -- * Various helpers
, updateIndex
, matchTemplate

) where

import Numeric (showHex, readHex)
import Control.Monad (liftM2)

import Data.Char (ord, chr)
import Data.Word (Word8)
import Data.Bits ((.|.), shiftL, shiftR)
import Data.List (unfoldr)
import Data.Binary 
    ( Binary
    , encode
    , decode
    , decodeOrFail
    )
import Data.Binary.Get
    ( Get
    , runGetOrFail
    , getByteString
    , ByteOffset
    , runGet
    )
import Data.Binary.Put (Put, runPut)

import qualified Data.ByteString.Lazy as BL 
    ( ByteString
    , toChunks
    , fromChunks
    )
import qualified Data.ByteString as BS 
    ( ByteString
    , concat
    , pack, unpack
    , append
    , length
    , cons
    , span
    , replicate
    , empty
    , null
    )

-- ByteString helpers

-- | Transforms a lazy bytestring into a strict bytestring
toStrictBS :: BL.ByteString -> BS.ByteString
toStrictBS = BS.concat . BL.toChunks

-- | Transforms a strict bytestring into a lazy bytestring
toLazyBS :: BS.ByteString -> BL.ByteString
toLazyBS bs = BL.fromChunks [bs]

-- | Transforms a string into a strict bytestring
stringToBS :: String -> BS.ByteString
stringToBS s = BS.pack $ map (fromIntegral . ord) s

-- | Transform a strict bytestring to a string
bsToString :: BS.ByteString -> String
bsToString bs = map (chr . fromIntegral) (BS.unpack bs)

-- | Decode a big endian Integer from a bytestring
bsToInteger :: BS.ByteString -> Integer
bsToInteger = (foldr f 0) . reverse . BS.unpack
  where 
    f w n = (toInteger w) .|. shiftL n 8

-- | Encode an Integer to a bytestring as big endian
integerToBS :: Integer -> BS.ByteString
integerToBS 0 = BS.pack [0]
integerToBS i 
    | i > 0     = BS.pack $ reverse $ unfoldr f i
    | otherwise = error "integerToBS not defined for negative values"
  where 
    f 0 = Nothing
    f x = Just $ (fromInteger x :: Word8, x `shiftR` 8)

-- | Encode a bytestring to a base16 (HEX) representation
bsToHex :: BS.ByteString -> String
bsToHex bs 
    | BS.null bs = ""
    | otherwise  = bsToString $ z2 `BS.append` r2
  where 
    (z,r) = BS.span (== 0) bs
    z2    = BS.replicate (BS.length z * 2) 48
    r1 | BS.null r = BS.empty
       | otherwise = stringToBS $ showHex (bsToInteger r) ""
    r2 | odd (BS.length r1) = BS.cons 48 r1
       | otherwise          = r1

-- | Decode a base16 (HEX) string from a bytestring. This function can fail
-- if the string contains invalid HEX characters
hexToBS :: String -> Maybe BS.ByteString
hexToBS str
    | null str  = Just BS.empty
    | otherwise = liftM2 BS.append (Just z2) r2
  where 
    (z,r) = span (== '0') str
    z2    = BS.replicate (length z `div` 2) 0
    r1    = readHex r
    r2 | null r    = Just BS.empty
       | null r1   = Nothing
       | otherwise = Just $ integerToBS $ fst $ head r1

-- Data.Binary helpers

-- | Strict version of @Data.Binary.encode@
encode' :: Binary a => a -> BS.ByteString
encode' = toStrictBS . encode

-- | Strict version of @Data.Binary.decode@
decode' :: Binary a => BS.ByteString -> a
decode' = decode . toLazyBS

-- | Strict version of @Data.Binary.runGet@
runGet' :: Binary a => Get a -> BS.ByteString -> a
runGet' m = (runGet m) . toLazyBS

-- | Strict version of @Data.Binary.runPut@
runPut' :: Put -> BS.ByteString
runPut' = toStrictBS . runPut

-- | Strict version of @Data.Binary.decodeOrFail@
decodeOrFail' :: 
    Binary a => 
    BS.ByteString -> 
    Either (BS.ByteString, ByteOffset, String) (BS.ByteString, ByteOffset, a)
decodeOrFail' bs = case decodeOrFail $ toLazyBS bs of
    Left  (lbs,o,err) -> Left  (toStrictBS lbs,o,err)
    Right (lbs,o,res) -> Right (toStrictBS lbs,o,res)

-- | Strict version of @Data.Binary.runGetOrFail@
runGetOrFail' ::
    Binary a => Get a -> BS.ByteString ->
    Either (BS.ByteString, ByteOffset, String) (BS.ByteString, ByteOffset, a)
runGetOrFail' m bs = case runGetOrFail m $ toLazyBS bs of
    Left  (lbs,o,err) -> Left  (toStrictBS lbs,o,err)
    Right (lbs,o,res) -> Right (toStrictBS lbs,o,res)

-- | Try to decode a Data.Binary value. If decoding succeeds, apply the function
-- to the result. Otherwise, return the default value.
fromDecode :: Binary a 
           => BS.ByteString -- ^ The bytestring to decode
           -> b             -- ^ Default value to return when decoding fails 
           -> (a -> b)      -- ^ Function to apply when decoding succeeds 
           -> b             -- ^ Final result
fromDecode bs def f = either (const def) (f . lst) $ decodeOrFail' bs
  where 
    lst (_,_,c) = c

-- | Try to run a Data.Binary.Get monad. If decoding succeeds, apply a function
-- to the result. Otherwise, return the default value.
fromRunGet :: Binary a 
           => Get a         -- ^ The Get monad to run
           -> BS.ByteString -- ^ The bytestring to decode
           -> b             -- ^ Default value to return when decoding fails 
           -> (a -> b)      -- ^ Function to apply when decoding succeeds 
           -> b             -- ^ Final result
fromRunGet m bs def f = either (const def) (f . lst) $ runGetOrFail' m bs
  where 
    lst (_,_,c) = c

-- | Decode a Data.Binary value into the Either monad. A Right value is returned
-- with the result upon success. Otherwise a Left value with the error message
-- is returned.
decodeToEither :: Binary a => BS.ByteString -> Either String a
decodeToEither bs = case decodeOrFail' bs of
    Left  (_,_,err) -> Left err
    Right (_,_,res) -> Right res

-- | Decode a Data.Binary value into the Maybe monad. A Just value is returned
-- with the result upon success. Otherwise, Nothing is returned.
decodeToMaybe :: Binary a => BS.ByteString -> Maybe a
decodeToMaybe bs = fromDecode bs Nothing Just

-- | Isolate a Data.Binary.Get monad for the next @Int@ bytes. Only the next
-- @Int@ bytes of the input bytestring will be available for the Get monad to
-- consume. This function will fail if the Get monad fails or some of the input
-- is not consumed.
isolate :: Binary a => Int -> Get a -> Get a
isolate i g = do
    bs <- getByteString i
    case runGetOrFail' g bs of
        Left (_, _, err) -> fail err
        Right (unconsumed, _, res)
            | BS.null unconsumed -> return res
            | otherwise          -> fail "Isolate: unconsumed input"

-- Maybe and Eithre monad helpers

-- | Returns True if the Either value is Right
isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _         = False

-- | Returns True if the Either value is Left
isLeft :: Either a b -> Bool
isLeft = not . isRight

-- | Extract the Right value from an Either value. Fails if the value is Left
fromRight :: Either a b -> b
fromRight (Right b) = b
fromRight _ = error "Either.fromRight: Left"

-- | Extract the Left value from an Either value. Fails if the value is Right
fromLeft :: Either a b -> a
fromLeft (Left a) = a
fromLeft _ = error "Either.fromLeft: Right"

-- | Transforms an Either value into a Maybe value. Right is mapped to Just
-- and Left is mapped to Nothing. The value inside Left is lost.
eitherToMaybe :: Either a b -> Maybe b
eitherToMaybe (Right b) = Just b
eitherToMaybe _ = Nothing

-- | Transforms a Maybe value into an Either value. Just is mapped to Right and
-- Nothing is mapped to Left. You also pass in an error value in case Left is
-- returned.
maybeToEither :: b -> Maybe a -> Either b a
maybeToEither err m = maybe (Left err) Right m

-- Various helpers

-- | Applies a function to only one element of a list defined by it's index.
-- If the index is out of the bounds of the list, the original list is returned
updateIndex :: Int      -- ^ The index of the element to change
            -> [a]      -- ^ The list of elements
            -> (a -> a) -- ^ The function to apply
            -> [a]      -- ^ The result with one element changed
updateIndex i xs f 
    | i < 0 || i >= length xs = xs
    | otherwise = l ++ (f h : r)
  where 
    (l,h:r) = splitAt i xs

-- | Use the list [b] as a template and try to match the elements of [a]
-- against it. For each element of [b] return the (first) matching element of
-- [a], or Nothing. Output list has same size as [b] and contains results in
-- same order.
matchTemplate :: [a]              -- ^ The input list
              -> [b]              -- ^ The list to serve as a template 
              -> (a -> b -> Bool) -- ^ The comparison function
              -> [Maybe a]        -- ^ Results of the template matching
matchTemplate [] bs _ = replicate (length bs) Nothing
matchTemplate _  [] _ = []
matchTemplate as (b:bs) f = case break (flip f b) as of
    (l,(r:rs)) -> (Just r) : matchTemplate (l ++ rs) bs f
    _          -> Nothing  : matchTemplate as bs f

