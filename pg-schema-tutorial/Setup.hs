{-# LANGUAGE OverloadedStrings #-}
import Debug.Trace
import Distribution.Simple
import PgSchema

main = do
  updateSchemaFile
    "app/Sch.hs"
    (Left "PG_SCHEMA_TUTORIAL_DB")
    "Sch" -- ^ haskell module name to generate
    "Sch" -- ^ name of generated haskell type for schema
    ["sch"] -- ^ name of schemas in database
  defaultMain
