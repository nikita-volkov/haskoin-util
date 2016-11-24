{-|
  Declaration of constant values for Prodnet. This module is intended to be
  imported by Network.Haskoin.Util.Network module and not imported directly by
  other modules.
-}
module Network.Haskoin.Util.Network.Prodnet where

import Data.Word (Word8,Word32)

-- | Prefix for base58 PubKey hash address
addrPrefix :: Word8
addrPrefix = 0

-- | Prefix for base58 script hash address
scriptPrefix :: Word8
scriptPrefix = 5

-- | Prefix for private key WIF format
secretPrefix :: Word8
secretPrefix = 128

-- | Prefix for extended public keys (BIP32)
extPubKeyPrefix :: Word32
extPubKeyPrefix = 0x0488b21e

-- | Prefix for extended private keys (BIP32)
extSecretPrefix :: Word32
extSecretPrefix = 0x0488ade4

-- | Wallet database file name
walletFile :: String
walletFile = "walletdb"

