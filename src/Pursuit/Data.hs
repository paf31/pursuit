{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DeriveDataTypeable #-}

module Pursuit.Data where

import Prelude hiding (mod)

import Data.Version
import Data.Char (toLower)
import Data.Typeable
import Data.IxSet hiding ((&&&))

import Data.Aeson ((.:))
import qualified Data.Aeson as A

import qualified Data.Text.Lazy as TL

import qualified Lucid as L

import Control.Arrow
import Control.Applicative

-- This is what appears in the packages.json file
data PackageDesc = PackageDesc { packageDescName    :: PackageName
                               , packageDescLocator :: Locator
                               }
                               deriving (Show)

instance A.FromJSON PackageDesc where
  parseJSON (A.Object o) =
    PackageDesc <$> o .: "bowerName"
                <*> o .: "github"
  parseJSON val = fail $ "couldn't parse " ++ show val ++ " as PackageDesc"

newtype PackageName = PackageName String
  deriving (Show, Eq, Ord, Typeable, A.FromJSON, L.ToHtml)

withPackageName :: (String -> String) -> PackageName -> PackageName
withPackageName f (PackageName str) = PackageName (f str)

runPackageName :: PackageName -> String
runPackageName (PackageName n) = n

-- A Locator describes where to find a particular package.
data Locator
  = OnGithub String String
  | BundledWithCompiler
  deriving (Show, Eq, Ord)

preludeWebUrl :: String
preludeWebUrl = "https://github.com/purescript/purescript/tree/master/prelude"

type GitUrl = String

toGitUrl :: Locator -> GitUrl
toGitUrl (OnGithub user repo) =
  "https://github.com/" ++ user ++ "/" ++ repo
toGitUrl BundledWithCompiler =
  "https://github.com/purescript/purescript"

instance A.FromJSON Locator where
  parseJSON (A.Object o) =
    OnGithub <$> o .: "user"
             <*> o .: "repo"
  parseJSON val = fail $ "couldn't parse " ++ show val ++ " as Locator"

packageDescGitUrl :: PackageDesc -> GitUrl
packageDescGitUrl = toGitUrl . packageDescLocator

-- A Package has a name (primary key), a Locator, and a Version.
data Package = Package { packageName    :: PackageName
                       , packageLocator :: Locator
                       , packageVersion :: Version
                       }
                       deriving (Show, Eq, Ord, Typeable)

-- This will need to change if we decide to support packages which are not
-- hosted on GitHub.
packageWebUrl :: Package -> String
packageWebUrl = toGitUrl . packageLocator

-- A Module belongs to exactly one Package. The primary key is composite:
-- (moduleName, modulePackageName)
data Module = Module { moduleName        :: ModuleName
                     , modulePackageName :: PackageName
                     }
                     deriving (Show, Eq, Ord, Typeable)

newtype ModuleName = ModuleName String
  deriving (Show, Eq, Ord, Typeable, L.ToHtml)

withModuleName :: (String -> String) -> ModuleName -> ModuleName
withModuleName f (ModuleName str) = ModuleName (f str)

-- A Decl belongs to exactly one Module. The primary key is composite:
-- (declName, declModule)
data Decl = Decl { declName   :: DeclName
                 , declDetail :: DeclDetail
                 , declModule :: (ModuleName, PackageName)
                 }
                 deriving (Show, Eq, Ord, Typeable)

newtype DeclName = DeclName String
  deriving (Show, Eq, Ord, Typeable, L.ToHtml)
newtype DeclDetail = DeclDetail TL.Text
  deriving (Show, Eq, Ord, Typeable, L.ToHtml)

withDeclName :: (String -> String) -> DeclName -> DeclName
withDeclName f (DeclName str) = DeclName (f str)

singleton :: a -> [a]
singleton = (:[])

lower :: String -> String
lower = map toLower

lowerP :: PackageName -> PackageName
lowerP = withPackageName lower

lowerM :: ModuleName -> ModuleName
lowerM = withModuleName lower

lowerD :: DeclName -> DeclName
lowerD = withDeclName lower

instance Indexable Package where
  empty = ixSet [ ixFun (singleton . lowerP . packageName) ]

instance Indexable Module where
  empty = ixSet [ ixFun (singleton . (lowerM . moduleName &&&
                                      lowerP . modulePackageName))
                , ixFun (singleton . lowerM . moduleName)
                , ixFun (singleton . lowerP . modulePackageName)
                ]

instance Indexable Decl where
  empty = ixSet [ ixFun (\d -> let (mod, pkg) = declModule d
                               in singleton (lowerD (declName d),
                                             lowerM mod,
                                             lowerP pkg))
                , ixFun (singleton . lowerD . declName)
                , ixFun (singleton . declDetail)
                ]
