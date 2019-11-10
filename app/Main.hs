{-# LANGUAGE NamedFieldPuns #-}
module Main where

import           Language.Docker               as Docker
import qualified Data.Text.IO                  as Text
import qualified Data.Text                     as Text
import           Data.Maybe                     ( mapMaybe )
import           Data.List                      ( mapAccumL )
import           Data.Text.Lazy                 ( toStrict )

import           Turtle
import           Options.Applicative           as Opt
import qualified Options.Applicative.Types     as Opt

import           Docker.StageRenamer            ( addAliases
                                                , extractAliases
                                                , extractUnnamedStages
                                                )

data GlobalOpts
  = GlobalOpts {dockerfilePath :: Turtle.FilePath, missingPrefix :: Text.Text }
  deriving (Eq, Show)

data Command
  = ListStages GlobalOpts
  | NeedsRewrite GlobalOpts
  | Rewrite GlobalOpts (Maybe Turtle.FilePath)
  deriving (Eq, Show)

parser :: Parser Command
parser = subparser
  (  Opt.command
      "list-stages"
      (Opt.info
        (ListStages <$> parseGlobalOpts)
        (Opt.progDesc
          "Lists all stages in a dockerfile. If the stage is unnamed, then a temporary stage name is output."
        )
      )
  <> Opt.command
       "needs-rewrite"
       (Opt.info
         (NeedsRewrite <$> parseGlobalOpts)
         (Opt.progDesc
           "Exit 0 if the specified Dockerfile does not need to be rewritten, exits 1 if it does need to be rewritten"
         )
       )
  <> Opt.command
       "rewrite"
       (Opt.info
         (Rewrite <$> parseGlobalOpts <*> parseTarget)
         (Opt.progDesc
           "Rewrites the specified Dockerfile to ensure each stage is named. May reformat dockerfile and remove comments."
         )
       )
  )
 where
  parseGlobalOpts = GlobalOpts <$> parsePath <*> parsePrefix

  parsePrefix     = Opt.option
    (Opt.maybeReader (Just . Text.pack))
    (  Opt.long "prefix"
    <> Opt.short 'p'
    <> Opt.metavar "PREFIX"
    <> Opt.value "unnamed"
    <> Opt.help "Prefix for unnamed stages"
    )

  parsePath = Opt.option
    toPath
    (  Opt.long "file"
    <> Opt.short 'f'
    <> Opt.metavar "FILENAME"
    <> Opt.value "Dockerfile"
    <> Opt.help "Name of the Dockerfile"
    <> Opt.completer (Opt.bashCompleter "file")
    )

  parseTarget = Opt.option
    (Just <$> toPath)
    (  Opt.long "output-path"
    <> Opt.short 'o'
    <> Opt.metavar "TARGET"
    <> Opt.value Nothing
    <> Opt.help "Path to output rewritten dockerfile"
    <> Opt.completer (Opt.bashCompleter "file")
    )

  toPath = Opt.maybeReader (Just . fromText . Text.pack)


main :: IO ()
main = do
  cmd <- options "Enables proper handling of multiphase dockerfiles" parser
  case cmd of
    ListStages   opts   -> doListAliases opts
    NeedsRewrite opts   -> doNeedsRewrite opts
    Rewrite opts target -> doRewrite opts target


doListAliases :: GlobalOpts -> IO ()
doListAliases GlobalOpts { dockerfilePath, missingPrefix } = processDockerfile
  dockerfilePath
  listAction
 where
  listAction dockerfile = do
    let aliases = addAliases missingPrefix dockerfile
    mapM_ Text.putStrLn (extractAliases aliases)


doNeedsRewrite GlobalOpts { dockerfilePath, missingPrefix } = processDockerfile
  dockerfilePath
  needsRewriteAction
 where
  needsRewriteAction dockerfile = do
    let missing = extractUnnamedStages dockerfile
    unless (null missing) $ exit (ExitFailure 1)


doRewrite GlobalOpts { dockerfilePath, missingPrefix } targetPath =
  processDockerfile dockerfilePath rewriteAction
 where
  rewriteAction dockerfile = do
    let fixedFile = addAliases missingPrefix dockerfile
        formatted = toStrict $ Docker.prettyPrint fixedFile
    case targetPath of
      Nothing -> Text.putStrLn formatted
      Just t  -> Text.writeFile (Text.unpack $ format fp t) formatted


processDockerfile targetFile processor = do
  parsed <- Docker.parseFile (Text.unpack (format fp targetFile))
  case parsed of
    Left err ->
      error $ "Could not parse dorckerfile: " ++ Docker.errorBundlePretty err
    Right dockerfile -> processor dockerfile
