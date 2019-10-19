{-# LANGUAGE CPP                     #-}
{-# LANGUAGE NoDuplicateRecordFields #-}
{-# LANGUAGE UndecidableInstances    #-}
{-# LANGUAGE UndecidableSuperClasses #-}
module Database.Schema.Def where

import Data.Kind
import Data.List as L
import Data.Map as M
import Data.Semigroup ((<>))
import Data.Singletons.Prelude as SP
import Data.Singletons.Prelude.List as SP
import Data.Singletons.TH
import Data.Text as T
import Util.ShowType
import Util.TH.LiftType
import Util.ToStar


singletons [d|

  data NameNS' s = NameNS
    { nnsNamespace  :: s
    , nnsName       :: s }
    deriving (Show, Eq, Ord)

  data TypDef' s = TypDef
    { typCategory :: s
    , typElem     :: Maybe (NameNS' s)
    , typEnum     :: [s] }
    deriving (Show, Eq, Ord)

  data FldDef' s = FldDef
    { fdType        :: NameNS' s
    , fdNullable    :: Bool
    , fdHasDefault  :: Bool }
    deriving (Show, Eq, Ord)

  data TabDef' s = TabDef
    { tdFlds       :: [s]
    , tdKey        :: [s]
    , tdUniq       :: [[s]] }
    -- , tdFrom       :: [NameNS' s]
    -- , tdTo         :: [NameNS' s] }
    deriving (Show, Eq, Ord)

  data RelDef' s = RelDef
    { rdFrom    :: NameNS' s
    , rdTo      :: NameNS' s
    , rdCols    :: [(s,s)] }
    deriving (Show, Eq, Ord)

  data TabRel' s = TabRel
    { trFrom       :: [NameNS' s]
    , trTo         :: [NameNS' s] }
    deriving (Show, Eq, Ord)

  zip2With :: (a -> b -> c) -> [a] -> [[b]] -> [[c]]
  zip2With f as = L.zipWith (\a -> L.map (f a)) as

  map2 :: (a -> b) -> [a] -> [(a,b)]
  map2 f as = L.map (\a -> (a, f a)) as

  map3 :: (b -> c) -> (a -> [b]) -> [a] -> [[(b,c)]]
  map3 f g xs = L.map (map2 f . g) xs

  data FldKind' s
    = FldPlain
    -- ^ simple field
    | FldTo (RelDef' s)
    -- ^ other records refer to this field (type is List)
    | FldFrom (RelDef' s)
    -- ^ field points to another record
    | FldUnknown s
    deriving (Show, Eq, Ord)

  |]

promote [d|
  getRelTab
    :: Eq s => [(NameNS' s, RelDef' s)] -> [(NameNS' s, RelDef' s)] -> s -> NameNS' s
  getRelTab froms tos s = case L.find cmpName froms of
    Just (_,rd) -> rdTo rd
    _ -> case L.find cmpName tos of
      Just (_,rd) -> rdFrom rd
      _           -> error "No relation by name"
    where
      cmpName ((NameNS _ r),_) = r == s

  getFldKind
    :: Eq s
    => TabDef' s -> [(NameNS' s, RelDef' s)] -> [(NameNS' s, RelDef' s)] -> s
    -> FldKind' s
  getFldKind (TabDef flds _ _) froms tos s =
    case L.find (== s) flds of
      Just _ -> FldPlain
      _ -> case L.find cmpName froms of
        Just (_,x) -> FldFrom x
        _      -> case L.find cmpName tos of
          Just (_,x) -> FldTo x
          _          -> FldUnknown s
    where
      cmpName ((NameNS _ r),_) = r == s

  isAllMandatory' :: Eq s => (s -> FldDef' s) -> [s] -> [s] -> Bool
  isAllMandatory' f tabFlds recFlds =
    L.null $ L.filter (isMandatory . f) tabFlds L.\\ recFlds
    where
      isMandatory fd = not (fdNullable fd || fdHasDefault fd)

  |]

type NameNSK = NameNS' Symbol
type TypDefK = TypDef' Symbol
type FldDefK = FldDef' Symbol
type TabDefK = TabDef' Symbol
type RelDefK = RelDef' Symbol
type TabRelK = TabRel' Symbol
type FldKindK = FldKind' Symbol

type NameNS = NameNS' Text
type TypDef = TypDef' Text
type FldDef = FldDef' Text
type TabDef = TabDef' Text
type RelDef = RelDef' Text
type TabRel = TabRel' Text
type FldKind = FldKind' Text

infixr 9 ->>
(->>) :: Text -> Text -> NameNS
(->>) = NameNS

type ns ->> name = 'NameNS ns name

-- CTypDef
-- | instances will be generated by TH
class
  (ToStar name, ToStar (TTypDef sch name)) => CTypDef sch (name :: NameNSK) where

  type TTypDef sch name :: TypDefK

typDef :: forall sch name. CTypDef sch name => TypDef
typDef = toStar @(TTypDef sch name)
genDefunSymbols [''TTypDef]

-- CFldDef
-- | instances will be generated by TH
class
  ( ToStar fname, ToStar tname
  , ToStar (TFldDef sch tname fname)
  , CTypDef sch (FdType (TFldDef sch tname fname)) )
  => CFldDef sch (tname::NameNSK) (fname::Symbol) where
  type TFldDef sch tname fname :: FldDefK

fldDef :: forall sch tname fname. CFldDef sch tname fname => FldDef
fldDef = toStar @(TFldDef sch tname fname)

genDefunSymbols [''TFldDef]

-- CTabDef
-- | instances will be generated by TH
class
  ( ToStar name, ToStar (TTabDef sch name)
  , ToStar (SP.Map (TFldDefSym2 sch name) (TdFlds (TTabDef sch name)))
  , ToStar (SP.Map (TFldDefSym2 sch name) (TdKey (TTabDef sch name)))
  , ToStar
    (SP.Map (SP.MapSym1 (TFldDefSym2 sch name)) (TdUniq (TTabDef sch name)))
  , ToStar
    ( ConcatMap (MapSym1 (TFldDefSym2 sch name)) (TdUniq (TTabDef sch name)) )
  ) => CTabDef sch (name::NameNSK) where

  type TTabDef sch name :: TabDefK

type TFromTab sch name = RdFrom (TRelDef sch name)
type TFromFlds sch name = SP.Map FstSym0 (RdCols (TRelDef sch name))
type TToTab sch name = RdTo (TRelDef sch name)
type TToFlds sch name = SP.Map SndSym0 (RdCols (TRelDef sch name))

-- CRelDef
-- | instances will be generated by TH
class
  ( ToStar name, ToStar (TRelDef sch name)
  , CTabDef sch (TFromTab sch name)
  , CTabDef sch (TToTab sch name)
  , ToStar (SP.Map (TFldDefSym2 sch (TFromTab sch name)) (TFromFlds sch name))
  , ToStar (SP.Map (TFldDefSym2 sch (TToTab sch name)) (TToFlds sch name))
  )
  => CRelDef sch (name::NameNSK) where

  type TRelDef sch name :: RelDefK

genDefunSymbols [''TTabDef, ''TRelDef]
-- we can also defun CTabDef and CRelDef but this is not needed

type TTabRelFrom sch tab = Map2 (TRelDefSym1 sch) (TFrom sch tab)
type TTabRelTo sch tab = Map2 (TRelDefSym1 sch) (TTo sch tab)

class CTabRels sch (tab :: NameNSK) where
  type TFrom sch tab :: [NameNSK]
  type TTo sch tab :: [NameNSK]

genDefunSymbols [''TFrom, ''TTo]

type IsAllMandatory sch t rs =
  IsAllMandatory' (TFldDefSym2 sch t) (TdFlds (TTabDef sch t)) rs

type TFieldKind sch tab name =
  GetFldKind (TTabDef sch tab) (TTabRelFrom sch tab) (TTabRelTo sch tab) name

-- | instances will be generated by TH
class
  ( ToStar (TTabs sch) --, ToStar (TRels sch)
  , ToStar (TTabRelFroms sch)
  , ToStar (TTabRelTos sch)
  , ToStar (TTabFldDefs sch)
  , ToStar (TTabFlds sch)
  , ToStar (TTabDefs sch)
  , ToStar (TTypes sch)
  , ToStar (SP.Map (TTypDefSym1 sch) (TTypes sch))
  )
  => CSchema sch where

  type TTabs sch    :: [NameNSK]
  -- type TRels sch    :: [NameNSK]
  type TTypes sch   :: [NameNSK]

-- type TRelDefs sch = Map2 (TRelDefSym1 sch) (TRels sch)
type TTabDefs sch = SP.Map (TTabDefSym1 sch) (TTabs sch)
type TTabFlds sch = SP.Map TdFldsSym0 (TTabDefs sch)
type TTabFldDefs sch =
  Zip2With (TFldDefSym1 sch) (TTabs sch) (TTabFlds sch)
type TTabRelFroms sch = Map3 (TRelDefSym1 sch) (TFromSym1 sch) (TTabs sch)
type TTabRelTos sch = Map3 (TRelDefSym1 sch) (TToSym1 sch) (TTabs sch)

--
data TabInfo = TabInfo
  { tiDef  :: TabDef
  , tiFlds :: M.Map Text FldDef
  , tiFrom :: M.Map NameNS RelDef
  , tiTo   :: M.Map NameNS RelDef }
  deriving (Show, Eq, Ord)

tabInfoMap :: forall sch. CSchema sch => M.Map NameNS TabInfo
tabInfoMap = M.fromList
  $ L.zip tabs
    $ L.zipWith4 TabInfo
      tabDefs
      (L.zipWith (\fs -> M.fromList . L.zip fs) tabFlds tabFldDefs)
      (M.fromList <$> tabRelFroms)
      (M.fromList <$> tabRelTos)
  where
    tabs = toStar @(TTabs sch)
    tabDefs = toStar @(TTabDefs sch)
    tabFlds = toStar @(TTabFlds sch)
    tabFldDefs = toStar @(TTabFldDefs sch)
    tabRelFroms = toStar @(TTabRelFroms sch)
    tabRelTos = toStar @(TTabRelTos sch)

typDefMap :: forall sch. CSchema sch => M.Map NameNS TypDef
typDefMap = M.fromList $ L.zip
  (toStar @(TTypes sch))
  (toStar @(SP.Map (TTypDefSym1 sch) (TTypes sch)))

#if !MIN_VERSION_base(4,11,0)
type (:====) a b = (:==) a b
#else
type (:====) a b = (==) a b
#endif

type TRelTab sch t name = GetRelTab
  (Map2 (TRelDefSym1 sch) (TFrom sch t)) (Map2 (TRelDefSym1 sch) (TTo sch t))
  name

type family TabOnPath sch (t :: NameNSK) (path :: [Symbol]) :: NameNSK where
  TabOnPath sch t '[] = t
  TabOnPath sch t (x ': xs) = TabOnPath sch (TRelTab sch t x) xs
--
type family TabPath sch (t :: NameNSK) (path :: [Symbol]) :: Constraint where
  TabPath sch t '[] = ()
  TabPath sch t (x ': xs) = TabPath sch (TRelTab sch t x) xs
--
instance LiftType NameNS where
  liftType NameNS{..} =
    [t| $(liftType nnsNamespace) ->> $(liftType nnsName) |]

instance LiftType TypDef where
  liftType TypDef{..} = [t| 'TypDef
    $(liftType typCategory) $(liftType typElem) $(liftType typEnum) |]

instance LiftType FldDef where
  liftType FldDef{..} = [t| 'FldDef
    $(liftType fdType) $(liftType fdNullable) $(liftType fdHasDefault) |]

instance LiftType TabDef where
  liftType TabDef{..} =
    [t| 'TabDef $(liftType tdFlds) $(liftType tdKey) $(liftType tdUniq) |]

instance LiftType RelDef where
  liftType RelDef{..} =
    [t| 'RelDef $(liftType rdFrom) $(liftType rdTo) $(liftType rdCols) |]
--
instance ShowType NameNS where
  showType NameNS{..} =
    "( " <> showType nnsNamespace <> " ->> " <> showType nnsName <> " )"

instance ShowType TypDef where
  showType TypDef{..} = "'TypDef " <> T.intercalate " "
    [showType typCategory, showType typElem, showType typEnum]

instance ShowType FldDef where
  showType FldDef{..} = "'FldDef " <> T.intercalate " "
    [showType fdType, showType fdNullable, showType fdHasDefault]

instance ShowType TabDef where
  showType TabDef{..} = "'TabDef " <> T.intercalate " "
    [showType tdFlds, showType tdKey, showType tdUniq]

instance ShowType RelDef where
  showType RelDef{..} = "'RelDef " <> T.intercalate " "
    [showType rdFrom, showType rdTo, showType rdCols]

qualName :: NameNS -> Text
qualName NameNS {..} = nnsNamespace <> "." <> nnsName
