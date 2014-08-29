{-# LANGUAGE TemplateHaskell #-}

module Data.ProtocolBuffers.TH where

import Control.Applicative
import Control.Monad
import Control.Monad.Trans

import Data.Char
import Data.Maybe
import Data.ProtocolBuffers (field)

-- template haskell
import Language.Haskell.TH
import Language.Haskell.TH.Syntax

-- lens package
import Control.Lens
import Control.Lens.TH
import Language.Haskell.TH.Lens

makeFieldLenses :: Quasi m => Name -> m [Dec]
makeFieldLenses name = runQ $ do

  -- generate "normal" lenses using the lens package
  lenses <- makeLenses name

  -- generate "normal . field" lens
  fields <- toFields lenses

  return $ fields

 where

  toFields :: [Dec] -> Q [Dec]
  toFields decs = fmap catMaybes . forM decs $ \dec -> do
    maybe (mkFun dec) (return . Just) =<< mkSig dec

  mkSig :: Dec -> Q (Maybe Dec)
  mkSig (SigD n (ForallT a b (AppT (AppT _iso tyT) aT))) = do
    mfieldT <- lookupTypeName "Data.ProtocolBuffers.FieldType"
    mlensT  <- lookupTypeName "Control.Lens.Lens'"
    case (mfieldT, mlensT) of
      (Just fieldT, Just lensT) -> return $ Just $
        SigD n (ForallT a b (AppT (AppT (ConT lensT) tyT) (AppT (ConT fieldT) aT)))
      _ -> return Nothing
  mkSig _ = return Nothing

  mkFun :: Dec -> Q (Maybe Dec)
  mkFun (FunD n _) = do
    mfield <- lookupValueName "Data.ProtocolBuffers.field"
    case mfield of
      Just fieldN -> do
        [dec] <- [d| $(varP n) = $(varE n) . $(varE fieldN) |]
        return $ Just dec
      _ -> return Nothing
  mkFun _ = return Nothing
