{-# LANGUAGE DuplicateRecordFields #-}
module Main where

import Control.Monad
import Data.Aeson
import Data.Aeson.TH
import Data.List as L
import Data.Text as T
import Data.Text.IO as T
import Database.PostgreSQL.DB
import Database.PostgreSQL.DML.Select
-- import Database.PostgreSQL.PgTagged
import Database.PostgreSQL.Simple
import Database.PostgreSQL.Simple.FromField
import Database.PostgreSQL.Simple.ToField
import Database.Schema.Rec
import Database.Schema.TH
import GHC.Generics
import Language.Haskell.TH
import Sch


data Country = Country
  { code :: Maybe Text
  , name :: Text }
  -- TODO: cycle references lead to halt! Should check to avoid it
  -- , city_country :: SchList City }
  deriving (Eq, Show, Ord, Generic)

data City = City
  { name         :: Maybe Text
  , city_country :: Country }
  deriving (Eq, Show, Ord, Generic)

data Address = Address
  { street       :: Maybe Text
  , home         :: Maybe Text
  , app          :: Maybe Text
  , zipcode      :: Maybe Text
  , address_city :: City } -- PgTagged "name" (Maybe Text) }
  deriving (Eq, Show, Ord, Generic)

L.concat
  <$> zipWithM (\n s ->
    L.concat <$> sequenceA
      [ deriveJSON defaultOptions n
      , [d|instance FromRow $(conT n)|]
      , [d|instance FromField $(conT n) where fromField = fromJSONField |]
      , [d|instance ToField $(conT n) where toField = toJSONField |]
      , schemaRec @Sch id n
      , [d|instance CQueryRecord PG Sch $(pure $ strToSym s) $(conT n)|]
      ])
  [ ''Country, ''City, ''Address]
  [ "countries", "cities", "addresses"]


main :: IO ()
main = do
  mapM_ T.putStrLn
    [ selectText @Sch @"countries" @Country
    , selectText @Sch @"cities" @City
    , selectText @Sch @"addresses" @Address
    ]
  conn <- connectPostgreSQL "dbname=schema_test user=avia host=localhost"
  selectSch_ @Sch @"countries" @Country conn >>= print
  selectSch_ @Sch @"cities" @City conn >>= print
  selectSch_ @Sch @"addresses" @Address conn >>= print
