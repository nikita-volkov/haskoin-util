{-|
  Declaration of constant values for Testnet. This module is intended to be
  imported by Network.Haskoin.Util.Network module and not imported directly by
  other modules.
-}
module Network.Haskoin.Util.Network.Testnet where

import Data.Word (Word8,Word32)

-- | Prefix for base58 PubKey hash address
addrPrefix :: Word8
addrPrefix = 111

-- | Prefix for base58 script hash address
scriptPrefix :: Word8
scriptPrefix = 196

-- | Prefix for private key WIF format
secretPrefix :: Word8
secretPrefix = 239

-- | Prefix for extended public keys (BIP32)
extPubKeyPrefix :: Word32
extPubKeyPrefix = 0x043587cf

-- | Prefix for extended private keys (BIP32)
extSecretPrefix :: Word32
extSecretPrefix = 0x04358394

-- | Wallet database file name
walletFile :: String
walletFile = "testwalletdb"

