{-# LANGUAGE CPP #-}
module Util.ShowType where

import Data.List as L
import Data.String
import Data.Text as T


#if !MIN_VERSION_base(4,11,0)
(<>) :: Monoid a => a -> a -> a
(<>) = mappend
#endif

class ShowType a where
  showType :: a -> Text

instance ShowType Text where
  showType = fromString . show

instance ShowType a => ShowType (Maybe a) where
  showType Nothing  = "'Nothing"
  showType (Just a) = "('Just " <> showType a <> ")"

instance ShowType Bool where
  showType True  = "'True"
  showType False = "'False"

instance ShowType a => ShowType [a] where
  showType = (\x -> "'[ " <> x <> " ]") . T.intercalate "," . L.map showType

instance (ShowType a, ShowType b) => ShowType (a,b) where
  showType (a,b) = "'( " <> showType a <> "," <> showType b <> " )"