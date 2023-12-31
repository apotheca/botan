module Main where

import Test.Prelude
import Botan.Low.Hash (HashName(..))

import Botan.Low.HOTP

key :: ByteString
key = "Fee fi fo fum"

counter :: HOTPCounter
counter = 12345

main :: IO ()
main = hspec $ testSuite hotpHashes chars $ \ h -> do
    it "hotpInit" $ do
        ctx <- hotpInit key h 6
        pass
    it "hotpGenerate" $ do
        ctx <- hotpInit key h 6
        code <- hotpGenerate ctx counter
        pass
    it "hotpCheck" $ do
        ctx <- hotpInit key h 6
        code <- hotpGenerate ctx counter
        (success,next) <- hotpCheck ctx code counter 0
        success `shouldBe` True
