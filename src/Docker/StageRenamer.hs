module Docker.StageRenamer where

import           Language.Docker               as Docker
import qualified Data.Text                     as Text
import           Data.List                      ( mapAccumL )
import           Data.Maybe                     ( mapMaybe )


addAliases :: Text.Text -> Docker.Dockerfile -> Docker.Dockerfile
addAliases prefixText instructions = snd $ mapAccumL addAlias 1 instructions
 where
  addAlias
    :: Int
    -> Docker.InstructionPos Text.Text
    -> (Int, Docker.InstructionPos Text.Text)
  addAlias number inst@InstructionPos { instruction = (From i@BaseImage { alias = Nothing }) }
    = ( number + 1
      , inst
        { instruction =
          From $ i
            { alias =
              Just (ImageAlias $ prefixText <> "-" <> Text.pack (show number))
            }
        }
      )
  addAlias number i = (number, i)


extractUnnamedStages :: Dockerfile -> [Instruction Text.Text]
extractUnnamedStages = mapMaybe (isUnnamedStage . Docker.instruction)
 where
  isUnnamedStage s@(From BaseImage { alias = Nothing }) = Just s
  isUnnamedStage _ = Nothing


extractAliases :: Dockerfile -> [Text.Text]
extractAliases = mapMaybe (isAlias . Docker.instruction)
 where
  isAlias (From BaseImage { alias = (Just (ImageAlias alias)) }) = Just alias
  isAlias _ = Nothing
