{-# LANGUAGE BinaryLiterals #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
{-# LANGUAGE LambdaCase     #-}
{-# LANGUAGE ViewPatterns   #-}

module Clash.Cores.LatticeSemi.IO
  ( sbio
  , spiConfig
  , PinOutputConfig(..)
  , PinInputConfig(..)
  ) where

import           Clash.Prelude
import           Clash.Signal.BiSignal       (BiSignalDefault(Floating))

toMaybe :: Bool -> a -> Maybe a
toMaybe True a = Just a
toMaybe False _a = Nothing

-- | Create configuration bitvector based on pin function mnemonics
spiConfig
  :: PinInputConfig
  -> PinOutputConfig
  -> BitVector 6
spiConfig pi po = pack po ++# pack pi

data PinInputConfig
  = PIN_INPUT_REGISTERED
  | PIN_INPUT
  | PIN_INPUT_REGISTERED_LATCH
  | PIN_INPUT_LATCH
-- Use PIN_INPUT_LATCH instead:
--  | PIN_INPUT_DDR
  deriving (Show, Generic, BitPack)

data PinOutputConfig
  = PIN_NO_OUTPUT
  | PIN_OUTPUT
  | PIN_OUTPUT_TRISTATE
  | PIN_OUTPUT_ENABLE_REGISTERED
  | PIN_OUTPUT_REGISTERED
  | PIN_OUTPUT_REGISTERED_ENABLE
  | PIN_OUTPUT_REGISTERED_ENABLE_REGISTERED
  | PIN_OUTPUT_DDR
  | PIN_OUTPUT_DDR_ENABLE
  | PIN_OUTPUT_DDR_ENABLE_REGISTERED
  | PIN_OUTPUT_REGISTERED_INVERTED
  | PIN_OUTPUT_REGISTERED_ENABLE_INVERTED
  | PIN_OUTPUT_REGISTERED_ENABLE_REGISTERED_INVERTED
  deriving (Show)

instance BitPack PinOutputConfig where
  type BitSize PinOutputConfig = 4
  pack =
    \case
      PIN_NO_OUTPUT -> 0b0000
      PIN_OUTPUT -> 0b0110
      PIN_OUTPUT_TRISTATE -> 0b1010
      PIN_OUTPUT_ENABLE_REGISTERED -> 0b1110
      PIN_OUTPUT_REGISTERED -> 0b0101
      PIN_OUTPUT_REGISTERED_ENABLE -> 0b1001
      PIN_OUTPUT_REGISTERED_ENABLE_REGISTERED -> 0b1101
      PIN_OUTPUT_DDR -> 0b0100
      PIN_OUTPUT_DDR_ENABLE -> 0b1000
      PIN_OUTPUT_DDR_ENABLE_REGISTERED -> 0b1100
      PIN_OUTPUT_REGISTERED_INVERTED -> 0b0111
      PIN_OUTPUT_REGISTERED_ENABLE_INVERTED -> 0b1011
      PIN_OUTPUT_REGISTERED_ENABLE_REGISTERED_INVERTED -> 0b1111

  unpack =
    \case
      0b0000 -> PIN_NO_OUTPUT
      0b0110 -> PIN_OUTPUT
      0b1010 -> PIN_OUTPUT_TRISTATE
      0b1110 -> PIN_OUTPUT_ENABLE_REGISTERED
      0b0101 -> PIN_OUTPUT_REGISTERED
      0b1001 -> PIN_OUTPUT_REGISTERED_ENABLE
      0b1101 -> PIN_OUTPUT_REGISTERED_ENABLE_REGISTERED

      0b0100 -> PIN_OUTPUT_DDR
      0b1000 -> PIN_OUTPUT_DDR_ENABLE
      0b1100 -> PIN_OUTPUT_DDR_ENABLE_REGISTERED

      0b0111 -> PIN_OUTPUT_REGISTERED_INVERTED
      0b1011 -> PIN_OUTPUT_REGISTERED_ENABLE_INVERTED
      0b1111 -> PIN_OUTPUT_REGISTERED_ENABLE_REGISTERED_INVERTED

      b -> errorX $ "Unrecognized bit pattern in PinOutputConfig.unpack: " <> show b

data OutputEnable
  = EnableLow
  | EnableHigh
  | EnablePass
  | EnableLatched
  deriving (Show, Generic, BitPack)

data OutputSelect
  = SelectDDR0
  | SelectDDR1
  | SelectD0
  | SelectLatchedInvertedD0
  deriving (Show, Generic, BitPack)

sbio
  :: ( HiddenClock dom  -- INPUT_CLK
     , HiddenEnable dom -- CLK_ENABLE
     )
  => BitVector 6
  -- ^ Config, see SBTICETechnologyLibrary201504.pdf, p88
  -> BiSignalIn 'Floating dom 1
  -- ^ PACKAGE_PIN
  -> Signal dom Bit
  -- ^ D_OUT_0
  -> Signal dom Bit
  -- ^ D_OUT_1 (Not implemented yet.)
  -> Signal dom Bool
  -- ^ OUTPUT_ENABLE
  -> ( BiSignalOut 'Floating dom 1  -- PACKAGE_PIN
     , Signal dom Bit               -- D_IN_0
     , Signal dom Bit               -- D_IN_1
     )
sbio pinConf pkgPinIn dOut_0 dOut_1 outputEnable0 =
  ( pkgPinOut
  , pure (errorX "d_in_0 not yet implemented")
  , pure (errorX "d_in_1 not yet implemented")
  )
 where
  outputEnable1 =
    case unpack (slice d5 d4 pinConf) of
      EnableLow     -> pure False
      EnableHigh    -> pure True
      EnablePass    -> outputEnable0
      EnableLatched -> error "OutputLatched: Not yet implemented"

  pkgPinWriteInput =
    case unpack (slice d3 d2 pinConf) of
      SelectD0 -> dOut_0
      opt -> error $ "OutputSelect." <> show opt <> " not yet implemented"

  pkgPinOut =
    writeToBiSignal
      pkgPinIn
      (toMaybe <$> outputEnable1 <*> pkgPinWriteInput)
