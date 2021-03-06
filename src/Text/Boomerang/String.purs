module Text.Boomerang.String where

import Prelude

import Data.Array as Data.Array
import Data.Foldable (class Foldable, elem)
import Data.Int (fromString)
import Data.List (List(..), fromFoldable, head)
import Data.Maybe (fromMaybe, Maybe(..))
import Data.String (fromCharArray, toCharArray)
import Data.Tuple (Tuple(..), fst)
import Text.Boomerang.Combinators (cons, list, maph, pureBmg)
import Text.Boomerang.HStack (hCons, hHead, hMap, hNil, HNil, hSingleton, (:-), type (:-))
import Text.Boomerang.Prim (Boomerang(..), Parsers(..), Serializer(..), runParsers', runSerializer)
import Text.Parsing.Parser.Pos (initialPos)
import Text.Parsing.Parser.String (eof)
import Text.Parsing.Parser.String as Text.Parsing.Parser.String

type StringBoomerang = Boomerang String


lit :: forall r. String -> StringBoomerang r r
lit s =
  Boomerang {
      prs : Parsers $ const id <$> Text.Parsing.Parser.String.string s
    , ser : Serializer (Just <<< Tuple (s <> _))
  }

string :: forall r. String -> StringBoomerang r (String :- r)
string s =
  Boomerang
    { prs : Parsers (hCons <$> Text.Parsing.Parser.String.string s)
    , ser : Serializer ser
    }
 where
  ser (s' :- t) =
    if s' == s
      then Just (Tuple (s <> _) t)
      else Nothing

oneOf :: forall r. Array Char -> StringBoomerang r (Char :- r)
oneOf a =
  Boomerang
    { prs : Parsers (hCons <$> Text.Parsing.Parser.String.oneOf a)
    , ser : Serializer ser
    }
 where
  ser (c :- t) =
    if c `elem` a
      then Just (Tuple (fromCharArray [c] <>  _) t)
      else Nothing

noneOf :: forall r. Array Char -> StringBoomerang r (Char :- r)
noneOf a =
  Boomerang {
      prs : Parsers (hCons <$> Text.Parsing.Parser.String.noneOf a)
    , ser : Serializer ser
  }
 where
  ser (c :- t) =
    if not (c `elem` a)
      then Just (Tuple (fromCharArray [c] <>  _) t)
      else Nothing

fromCharList :: forall f. Foldable f => f Char -> String
fromCharList = fromCharArray <<< Data.Array.fromFoldable

-- XXX: refactor this functions
manyOf :: forall r. String -> StringBoomerang r (String :- r)
manyOf a =
  pureBmg prs ser <<< list (oneOf a')
 where
  a' = toCharArray a
  prs = hMap fromCharList
  ser h = Just (hMap (fromFoldable <<< toCharArray) h)

many1Of :: forall r. String -> StringBoomerang r (String :- r)
many1Of a =
  pureBmg prs ser <<< cons <<< oneOf a' <<< list (oneOf a')
 where
  a' = toCharArray a
  prs = hMap fromCharList
  ser h = Just (hMap (fromFoldable <<< toCharArray) h)

manyNoneOf :: forall r. String -> StringBoomerang r (String :- r)
manyNoneOf a =
  pureBmg prs ser <<< list (noneOf a')
 where
  a' = toCharArray a
  prs = hMap fromCharList
  ser h = Just (hMap (fromFoldable <<< toCharArray) h)

many1NoneOf :: forall r. String -> StringBoomerang r (String :- r)
many1NoneOf a =
  pureBmg prs ser <<< cons <<< noneOf a' <<< list (noneOf a')
 where
  a' = toCharArray a
  prs = hMap fromCharList
  ser h = Just (hMap (fromFoldable <<< toCharArray) h)

digits :: forall r. StringBoomerang r (String :- r)
digits = many1Of "0123456789"

-- int :: forall r. Unit -> StringBoomerang r (Int :- r)
int :: forall r. Boomerang String r (Int :- r)
int =
  maph intPrs intSer <<< digits
 where
  intPrs :: String -> Int
  intPrs s = fromMaybe 0 (fromString s)

  intSer :: Int -> Maybe String
  intSer i = Just (show i)

parse :: forall a. StringBoomerang HNil (a :- HNil) -> String -> Maybe a
parse (Boomerang b) s = do
  let
    {left, right} = runParsers' s initialPos (do
      r <- b.prs
      pure r)
  case right of
    Nil -> Nothing
    l -> do
      f <- fst <$> head l
      pure (hHead (f hNil))

serialize :: forall a. StringBoomerang HNil (a :- HNil) -> a -> Maybe String
serialize (Boomerang b) s = do
  (Tuple f _) <- runSerializer b.ser (hSingleton s)
  pure (f "")
