{-|
Module      : Botan.Bindings.PubKey.ElGamal
Description : Algorithm specific key operations: ElGamal
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX
-}

{-# LANGUAGE CApiFFI #-}

module Botan.Bindings.PubKey.ElGamal where

import Botan.Bindings.MPI
import Botan.Bindings.Prelude
import Botan.Bindings.PubKey
import Botan.Bindings.RNG

{- |
Generates ElGamal key pair. Caller has a control over key length
and order of a subgroup 'q'. Function is able to use two types of
primes:

   * if pbits-1 == qbits then safe primes are used for key generation

   * otherwise generation uses group of prime order
-}
foreign import capi safe "botan/ffi.h botan_privkey_create_elgamal"
    botan_privkey_create_elgamal
        :: Ptr BotanPrivKey    -- ^ key handler to the resulting key
        -> BotanRNG            -- ^ rng initialized PRNG
        -> CSize               -- ^ pbits length of the key in bits. Must be at least 1024
        -> CSize               -- ^ qbits order of the subgroup. Must be at least 160
        -> IO CInt             -- ^ - BOTAN_FFI_SUCCESS Success, `key' initialized with DSA key
                               --   - BOTAN_FFI_ERROR_NULL_POINTER  either `key' or `rng' is NULL
                               --   - BOTAN_FFI_ERROR_BAD_PARAMETER unexpected value for either `pbits' or `qbits'
                               --   - BOTAN_FFI_ERROR_NOT_IMPLEMENTED functionality not implemented

-- | Loads ElGamal private key
foreign import capi safe "botan/ffi.h botan_pubkey_load_elgamal"
    botan_pubkey_load_elgamal
        :: Ptr BotanPubKey    -- ^ key variable populated with key material
        -> BotanMP            -- ^ p prime order of a Z_p group
        -> BotanMP            -- ^ g group generator
        -> BotanMP            -- ^ y private key
        -> IO CInt            -- ^ 0 on success, a negative value on failure

-- | Loads ElGamal public key
foreign import capi safe "botan/ffi.h botan_privkey_load_elgamal"
    botan_privkey_load_elgamal
        :: Ptr BotanPrivKey    -- ^ key variable populated with key material
        -> BotanMP             -- ^ p prime order of a Z_p group
        -> BotanMP             -- ^ g group generator
        -> BotanMP             -- ^ x public key
        -> IO CInt             -- ^ 0 on success, a negative value on failure           
