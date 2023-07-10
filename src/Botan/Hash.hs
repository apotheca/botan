module Botan.Hash where

import Prelude

import Control.Monad

import Data.ByteString (ByteString)

import Data.ByteArray (ByteArrayAccess(..), ByteArray(..))
import qualified Data.ByteArray as ByteArray

import Data.Word

import System.IO

import Foreign.C.Types
import Foreign.ForeignPtr
import Foreign.Marshal.Alloc
import Foreign.Ptr
import Foreign.Storable

import Botan.Error

import GHC.Stack

-- NOTE: Noticed that "MD5" is not supported / was not built into this release of botan?
--  This may require conditional compilation checks or something.

type OpaqueHash = Ptr ()

newtype Hash = Hash { hashForeignPtr :: ForeignPtr OpaqueHash }

foreign import ccall unsafe botan_hash_init :: Ptr OpaqueHash -> Ptr CChar -> Word32 -> IO BotanErrorCode
foreign import ccall "&botan_hash_destroy" botan_hash_destroy :: FunPtr (Ptr OpaqueHash -> IO ())

-- TODO: Discuss naming, eg init vs hashInit
--  It depends on whether we intend qualified import or not
hashInitName :: (ByteArray ba) => ba -> IO Hash
hashInitName name = withByteArray name $ \ namePtr -> do
    hashForeignPtr <- alloca $ newForeignPtr botan_hash_destroy
    withForeignPtr hashForeignPtr $ \ hashPtr -> do
        throwBotanIfNegative_ $ botan_hash_init hashPtr namePtr 0
    return $ Hash hashForeignPtr

foreign import ccall unsafe botan_hash_name :: OpaqueHash -> Ptr CChar -> Ptr CSize -> IO BotanErrorCode

hashName :: (ByteArray ba) => Hash -> IO ba
hashName (Hash hashForeignPtr) = withForeignPtr hashForeignPtr $ \ hashPtr -> do
    hash <- peek hashPtr
    alloca $ \ szPtr -> do
        bs <- ByteArray.alloc 64 $ \ bytes -> do
            throwBotanIfNegative_ $ botan_hash_name hash bytes szPtr
        sz <- peek szPtr
        return $ ByteArray.take (fromIntegral sz) bs

-- int botan_hash_copy_state(botan_hash_t *dest, const botan_hash_t source)
foreign import ccall unsafe botan_hash_copy_state :: Ptr OpaqueHash -> OpaqueHash -> IO BotanErrorCode

hashCopyState :: Hash -> IO Hash
hashCopyState = undefined

-- int botan_hash_clear(botan_hash_t hash)
foreign import ccall unsafe botan_hash_clear :: OpaqueHash -> IO BotanErrorCode

hashClear :: Hash -> IO ()
hashClear (Hash hashForeignPtr) = withForeignPtr hashForeignPtr $ \ hashPtr -> do
    hash <- peek hashPtr
    throwBotanIfNegative_ $ botan_hash_clear hash

foreign import ccall unsafe botan_hash_output_length :: OpaqueHash -> Ptr CSize -> IO Int

hashOutputLength :: Hash -> IO Int
hashOutputLength (Hash hashForeignPtr) = withForeignPtr hashForeignPtr $ \ hashPtr -> do
    hash <- peek hashPtr
    alloca $ \ szPtr -> do
        throwBotanIfNegative_ $ botan_hash_output_length hash szPtr
        fromIntegral <$> peek szPtr

-- int botan_hash_update(botan_hash_t hash, const uint8_t *input, size_t len)
foreign import ccall unsafe botan_hash_update :: OpaqueHash -> Ptr Word8  -> CSize -> IO BotanErrorCode

hashUpdate :: (ByteArray ba) => Hash -> ba -> IO ()
hashUpdate (Hash hashForeignPtr) ba = withForeignPtr hashForeignPtr $ \ hashPtr -> do
    hash <- peek hashPtr
    withByteArray ba $ \ baPtr -> do
        throwBotanIfNegative_ $ botan_hash_update hash baPtr (fromIntegral $ ByteArray.length ba)

-- int botan_hash_final(botan_hash_t hash, uint8_t out[])
foreign import ccall unsafe botan_hash_final :: OpaqueHash -> Ptr Word8 -> IO BotanErrorCode

hashFinal :: (ByteArray ba) => Hash -> IO ba
hashFinal (Hash hashForeignPtr) = withForeignPtr hashForeignPtr $ \ hashPtr -> do
    hash <- peek hashPtr
    sz <- alloca $ \ szPtr -> do
        throwBotanIfNegative_ $ botan_hash_output_length hash szPtr
        fromIntegral <$> peek szPtr
    ByteArray.alloc sz $ \ bytes -> do
        throwBotanIfNegative_ $ botan_hash_final hash bytes
