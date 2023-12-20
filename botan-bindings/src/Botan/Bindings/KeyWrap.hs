{-|
Module      : Botan.Bindings.KeyWrap
Description : Bcrypt password hashing
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX

NIST specifies two mechanisms for wrapping (encrypting) symmetric keys
using another key. The first (and older, more widely supported) method
requires the input be a multiple of 8 bytes long. The other allows any
length input, though only up to 2**32 bytes.

These algorithms are described in NIST SP 800-38F, and RFCs 3394 and 5649.

These functions take an arbitrary 128-bit block cipher. NIST only allows
these functions with AES, but any 128-bit cipher will do and some other
implementations (such as in OpenSSL) do also allow other ciphers.

Use AES for best interop.
-}

{-# LANGUAGE CApiFFI #-}

module Botan.Bindings.KeyWrap where

import Botan.Bindings.Prelude

foreign import capi safe "botan/ffi.h botan_nist_kw_enc"
    botan_nist_kw_enc
        :: ConstPtr CChar -- ^ cipher_algo
        -> CInt           -- ^ padded
        -> ConstPtr Word8 -- ^ key[]
        -> CSize          -- ^ key_len
        -> ConstPtr Word8 -- ^ kek[]
        -> CSize          -- ^ kek_len
        -> Ptr Word8      -- ^ wrapped_key[]
        -> Ptr CSize      -- ^ wrapped_key_len
        -> IO CInt

foreign import capi safe "botan/ffi.h botan_nist_kw_dec"
    botan_nist_kw_dec
        :: ConstPtr CChar -- ^ cipher_algo
        -> CInt           -- ^ padded
        -> ConstPtr Word8 -- ^ wrapped_key[]
        -> CSize          -- ^ wrapped_key_len
        -> ConstPtr Word8 -- ^ kek[]
        -> CSize          -- ^ kek_len
        -> Ptr Word8      -- ^ key[]
        -> Ptr CSize      -- ^ key_len
        -> IO CInt
