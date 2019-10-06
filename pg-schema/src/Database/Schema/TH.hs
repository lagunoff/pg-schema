module Database.Schema.TH where

import Data.List as L
import Data.String
import Data.Text as T
import Database.Schema.Def
import Database.Schema.Rec
import Language.Haskell.TH
import Util.TH.LiftType


schemaRec
  :: forall sch. CSchema sch => (String -> String) -> Name -> DecsQ
schemaRec toDbName rn = do
  fs <- reify rn >>= \case
    TyConI (DataD _ _ _ _ [RecC _ fs] _) -> pure fs
    TyConI (NewtypeD _ _ _ _ (RecC _ fs) _) -> pure fs
    x -> do
      reportError $ "schemaRec: Invalid pattern in reify: " ++ show x
      pure []

  i1 <- L.concat <$> traverse fieldTypeInst fs
  i2 <- traverse getFieldInfo fs >>= recordInfoInst . toPromotedList
  pure $ i2 ++ i1
  where
    fieldTypeInst (pack . nameBase -> tname,_,t) = [d|
      instance CFieldType $(liftType rn) $(liftType tname) where
        type TFieldType $(liftType rn) $(liftType tname) = $(pure t)
      |]

    getFieldInfo (nameBase -> sname, _, _) =
      [t|'FieldInfo $(liftType $ T.pack sname) $(liftType tDbName)|]
      where
        tDbName = fromString @Text $ toDbName sname

    recordInfoInst fis = [d|
      instance CRecordInfo $(liftType rn) where
        type TRecordInfo $(liftType rn) = $(pure fis)
      |]
