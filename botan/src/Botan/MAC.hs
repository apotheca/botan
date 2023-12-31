module Botan.MAC
( MAC(..)
, macName
, MACKey(..)
, MACNonce(..)
, Low.MACDigest(..)
, macCtxInitIO
, macCtxInit
, macCtxOutputLength
, macCtxSetKey
, macCtxSetNonce
, macCtxUpdate
, macCtxUpdates
, macCtxFinalize
, macCtxClear
, macCtxName
, macCtxGetKeyspec
, macCtxUpdateFinalizeIO
, macCtxUpdateFinalizeClearIO
, macWithMACCtxIO
, macWithMACCtx
, macWithNameIO
, macWithName
, macIO
, mac
) where

import Data.Foldable

import qualified Botan.Low.MAC as Low

import Botan.BlockCipher
import Botan.Hash
import Botan.RNG
import Botan.Prelude

-- NOTE: MAC has no state copy unlike Hash

-- NOTE: Botan MAC FFI is missing query for nonce sizes.

-- NOTE: Poly1305 does not appear to require a nonce, despite documentation:
--  > Due to the nonce requirement, Poly1305 is exceptionally fragile. Avoid it unless absolutely required.
-- I believe this is a nomenclature mixup, as there are MACs that require both key and nonce
-- However, this is Poly1305-Wegman-Carter which should only require a key - but the
-- key must not be reused, like a nonce.

data MAC
    = CMAC BlockCipher  -- NOTE: This is actually OMAC a CMAC variant
    | GMAC BlockCipher      -- Requires a nonce
    -- | CBC_MAC BlockCipher  -- No longer supported (possibly due to security issues) 
    | HMAC Hash    
    -- New in 3.2
    -- | KMAC_128 Int -- Output length
    -- | KMAC_256 Int -- Output length
    | Poly1305              -- Requires a unique key per message
    | SipHash Int Int       -- Number of input and finalization rounds
    | X9_19_MAC
    deriving (Show, Eq)
-- NOTE: Wiki: "Both GCM and GMAC can accept initialization vectors of arbitrary length." - untested

macName :: MAC -> ByteString
macName (CMAC bc)       = "CMAC(" <> blockCipherName bc <> ")"
macName (GMAC bc)       = "GMAC(" <> blockCipherName bc <> ")"
-- macName (CBC_MAC bc)    = "CBC-MAC(" <> blockCipherName bc <> ")"
macName (HMAC h)        = "HMAC(" <> hashName h <> ")"
macName Poly1305        = "Poly1305"
macName (SipHash ir fr) = "SipHash(" <> showBytes ir <> "," <> showBytes fr <> ")"
macName X9_19_MAC       = "X9.19-MAC"

-- NOTE: NOT CHECKED FOR CORRECTNESS YET
macNonceLength :: MAC -> Int
macNonceLength (CMAC _)      = 0
macNonceLength (GMAC _)      = 12 -- Probably incorrect for some ciphers - TODO: use cipherCtxGetDefaultNonceLength
-- macNonceLength (CBC_MAC _)   = 0
macNonceLength (HMAC _)      = 0
macNonceLength Poly1305      = 16   -- Is this Poly1305, or Poly1305-WC?
macNonceLength (SipHash _ _) = 0
macNonceLength X9_19_MAC     = 0
-- NOTE: Poly1305 takes a 32-byte key? But its supposed to take a 16-byte key.
--  Need to figure out specifics - what variant of Poly1305
{-
ghci> import Botan.MAC
ghci> import Botan.Utility 
ghci> import Botan.Low.RNG 
ghci> k <- systemRNGGetIO 16
ghci> mac Poly1305 k Nothing "Fee fi fo fum!"
"*** Exception: InvalidKeyLengthException (-34) [("throwBotanIfNegative_",SrcLoc {srcLocPackage = "botan-low-0.0.1-inplace", srcLocModule = "Botan.Low.Make", srcLocFile = "src/Botan/Low/Make.hs", srcLocStartLine = 346, srcLocStartCol = 9, srcLocEndLine = 346, srcLocEndCol = 30})]
ghci> k <- systemRNGGetIO 32
ghci> mac Poly1305 k Nothing "Fee fi fo fum!"
"\234\SO\211\187%\156\220o\134\&4\169\248\rr\134H"
-}

type MACKey = ByteString
type MACNonce = ByteString

data MACKeySpec
    = MACKeySpec
    { macKeyMinimum :: Int
    , macKeyMaximum :: Int
    , macKeyModulo  :: Int
    }
    deriving  (Show, Eq)

macCtxInitIO :: MAC -> IO Low.MAC
macCtxInitIO  mac = Low.macInit (macName mac)

macCtxInit :: MAC -> Low.MAC
macCtxInit = unsafePerformIO1 macCtxInitIO

macCtxOutputLength :: Low.MAC -> Int
macCtxOutputLength = unsafePerformIO1 Low.macOutputLength

macCtxSetKey :: Low.MAC -> MACKey -> Low.MAC
macCtxSetKey ctx key = unsafePerformIO $ do
    Low.macSetKey ctx key
    return ctx

-- NOTE: Not all MACs require a nonce
--  Eg, GMAC requires a nonce
--  Other MACs do not require a nonce, and will cause a BadParameterException (-32)
macCtxSetNonce :: Low.MAC -> MACNonce -> Low.MAC
macCtxSetNonce ctx nonce = unsafePerformIO $ do
    Low.macSetNonce ctx nonce
    return ctx

macCtxUpdate :: Low.MAC -> ByteString -> Low.MAC
macCtxUpdate ctx bytes = unsafePerformIO $ do
    Low.macUpdate ctx bytes
    return ctx

macCtxUpdates :: Low.MAC -> [ByteString] -> Low.MAC
macCtxUpdates ctx chunks = unsafePerformIO $ do
    traverse_ (Low.macUpdate ctx) chunks
    return ctx

macCtxFinalize :: Low.MAC -> Low.MACDigest
macCtxFinalize = unsafePerformIO1 Low.macFinal

-- NOTE: Not sure if this should be exposed
macCtxClear :: Low.MAC -> Low.MAC
macCtxClear ctx = unsafePerformIO $ do
    Low.macClear ctx
    return ctx

macCtxName :: Low.MAC -> Low.MACName
macCtxName = unsafePerformIO1 Low.macName

macCtxGetKeyspec :: Low.MAC -> MACKeySpec
macCtxGetKeyspec ctx = unsafePerformIO $ do
    (mn,mx,md) <- Low.macGetKeyspec ctx
    return $ MACKeySpec mn mx md

-- Convenience

macCtxUpdateFinalizeIO :: Low.MAC -> Message -> IO Low.MACDigest
macCtxUpdateFinalizeIO ctx bytes = do
    Low.macUpdate ctx bytes
    Low.macFinal ctx

macCtxUpdateFinalizeClearIO :: Low.MAC -> Message -> IO Low.MACDigest
macCtxUpdateFinalizeClearIO ctx bytes = do
    dg <- macCtxUpdateFinalizeIO ctx bytes
    Low.macClear ctx
    return dg

--

macWithMACCtxIO :: Low.MAC -> MACKey -> Maybe MACNonce -> Message -> IO Low.MACDigest
macWithMACCtxIO ctx key nonce message = do
    Low.macSetKey ctx key
    case nonce of
        Nothing -> Low.macSetNonce ctx ""
        Just n  -> Low.macSetNonce ctx n
    macCtxUpdateFinalizeClearIO ctx message

macWithMACCtx :: Low.MAC -> MACKey -> Maybe MACNonce -> Message -> Low.MACDigest
macWithMACCtx = unsafePerformIO4 macWithMACCtxIO

macWithNameIO :: Low.MACName -> MACKey -> Maybe MACNonce -> Message -> IO Low.MACDigest
macWithNameIO name key nonce message = do
    ctx <- Low.macInit name
    macWithMACCtxIO ctx key nonce message

macWithName :: Low.MACName -> MACKey -> Maybe MACNonce -> Message -> Low.MACDigest
macWithName = unsafePerformIO4 macWithNameIO

macIO :: MAC -> MACKey -> Maybe MACNonce -> Message -> IO Low.MACDigest
macIO = macWithNameIO . macName

mac :: MAC -> MACKey -> Maybe MACNonce -> Message -> Low.MACDigest
mac = unsafePerformIO4 macIO

-- TODO: stuff like newMACKey newMACNonce