module Main where

import Test.Framework (defaultMain)
import qualified Network.Haskoin.Util.Tests (tests)

main :: IO ()
main = defaultMain ( Network.Haskoin.Util.Tests.tests )

